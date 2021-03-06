## 피드백 수정사항
- 파싱된 데이터 캡쳐 추가 ( 3-apache2-filebeat02.png, 6-len_with_parsed_date01.png )
- 바로 파싱된 데이터를 얻기 위해 웹 컨테이너를 Apache2로 변경


## 웹/사이드카 컨테이너 선정
- 가이드에 노드-레벨 에이전트에 대한 언급이 없기 때문에 Pod에서 Elasticsearch로 바로 전달하기 위해 Filebeat로 사이드카를 선정하였습니다.
- 웹의 경우는 파싱 데이터를 편리하게 얻기 위해 apache2로 선정하였습니다.

## 엘라스틱서치는 데이터가 계속 보존될 수 있도록 해결책
- Elasticsearch를 StatefulSet으로 배치
- StorageClass는 기존의 rook를 사용하고 ReclaimPolicy를 retain으로 변경
- ```shell 
  kubectl patch pv pvc-87a2d9c0-b43b-4f7c-9a5b-b70d5dd27d6d -p '{"spec":{"persistentVolumeReclaimPolicy":"Retain"}}' 
  kubectl patch pv pvc-a82845ac-e489-4ec1-8915-361d681f8b33 -p '{"spec":{"persistentVolumeReclaimPolicy":"Retain"}}'
  kubectl patch pv pvc-acc9d896-f0c2-410a-af1f-b94bdf3cced4 -p '{"spec":{"persistentVolumeReclaimPolicy":"Retain"}}'
  ```
- 첨부된 3-kibana_startup.png의 log를 캡쳐를 위해 진행하기 전에 최초 진행한 7.14.1 버전의 로그가 보존되었음을 확인할 수 있습니다.


## 구축 과정
1. Elasticsearch와 Kibana 스택 구축
   - Namespace elastic-stack 생성
   - ```yaml
     kind: Namespace
     apiVersion: v1
     metadata:
       name: elastic-stack
     ```
   - Elasticsearch service와 StatefulSet 구성
   - Service의 경우 default Namespace에서 실행될 Apache2/Filebeat와의 통신을 위해서 ClusterIP를 할당
   - ```yaml
      kind: Service
      apiVersion: v1
      metadata:
        name: elasticsearch
        namespace: elastic-stack
        labels:
          app: elasticsearch
      spec:
        selector:
          app: elasticsearch
        ports:
          - port: 9200
            name: rest
          - port: 9300
            name: inter-node
        clusterIP: 10.110.91.85
      ```
   - ```yaml
      apiVersion: apps/v1
      kind: StatefulSet
      metadata:
        name: es-cluster
        namespace: elastic-stack
      spec:
        serviceName: elasticsearch
        replicas: 3
        selector:
          matchLabels:
            app: elasticsearch
        template:
          metadata:
            labels:
              app: elasticsearch
          spec:
            containers:
            - name: elasticsearch
              image: docker.elastic.co/elasticsearch/elasticsearch:7.16.1
              resources:
                  limits:
                    cpu: 1000m
                  requests:
                    cpu: 100m
              ports:
              - containerPort: 9200
                name: rest
                protocol: TCP
            - containerPort: 9300
              name: inter-node
              protocol: TCP
            volumeMounts:
            - name: data
              mountPath: /usr/share/elasticsearch/data
            env:
              - name: cluster.name
                value: web-logs
              - name: node.name
                valueFrom:
                  fieldRef:
                    fieldPath: metadata.name
              - name: discovery.seed_hosts
                value: "es-cluster-0.elasticsearch,es-cluster-1.elasticsearch,es-cluster-2.elasticsearch"
              - name: cluster.initial_master_nodes
                value: "es-cluster-0,es-cluster-1,es-cluster-2"
              - name: ES_JAVA_OPTS
                value: "-Xms512m -Xmx512m"
          initContainers:
          - name: fix-permissions
            image: busybox
            command: ["sh", "-c", "chown -R 1000:1000 /usr/share/elasticsearch/data"]
            securityContext:
              privileged: true
            volumeMounts:
            - name: data
              mountPath: /usr/share/elasticsearch/data
          - name: increase-vm-max-map
            image: busybox
            command: ["sysctl", "-w", "vm.max_map_count=262144"]
            securityContext:
              privileged: true
          - name: increase-fd-ulimit
            image: busybox
            command: ["sh", "-c", "ulimit -n 65536"]
            securityContext:
              privileged: true
      volumeClaimTemplates:
      - metadata:
          name: data
          labels:
            app: elasticsearch
        spec:
          accessModes: [ "ReadWriteOnce" ]
          storageClassName: rook-ceph-block 
          resources:
            requests:
              storage: 10G
     ```
   - Kibana Service와 Deploy 구성
   - NodePort를 통해 브라우저로 접속
   - ```yaml
        apiVersion: v1
        kind: Service
        metadata:
          name: kibana
          namespace: elastic-stack
          labels:
            app: kibana
        spec:
          ports:
          - port: 5601
          selector:
            app: kibana
          type: NodePort
        ---
        apiVersion: apps/v1
        kind: Deployment
        metadata:
          name: kibana
          namespace: elastic-stack
          labels:
            app: kibana
        spec:
          replicas: 1
          selector:
            matchLabels:
              app: kibana
          template:
            metadata:
              labels:
                app: kibana
            spec:
              terminationGracePeriodSeconds: 15
              containers:
              - name: kibana
                image: docker.elastic.co/kibana/kibana:7.16.1
                resources:
                  limits:
                    cpu: 1000m
                  requests:
                    cpu: 100m
                env:
                  - name: ELASTICSEARCH_URL
                    value: http://elasticsearch:9200
                ports:
                - containerPort: 5601
       ```
2. Web와 사이드카 배포 및 로그 생성
   - Filebeat을 위한 ConfigMap 생성 - [output.elasticsearch, apache module, var.paths]
   - 로그 생성을 위해 NodePort로 Apache Service 생성
   - Emptydir와 ConfigMap 마운트
   - ```yaml
      apiVersion: v1
      kind: ConfigMap
      metadata:
        name: filebeat-configmap
        labels:
          app: apache-filebeat
      data:
        filebeat.yml: |
          filebeat:
            config:
              modules:
                path: /usr/share/filebeat/modules.d/*.yml
                reload:
                  enabled: true
            modules:
            - module: apache
              access:
                var.paths: ["/var/log/apache2/access.log*"]
              error:
                var.paths: ["/var/log/apache2/error.log*"]
          output.elasticsearch:
              hosts: ["10.110.91.85:9200"]
      ---
      apiVersion: v1
      kind: Service
      metadata:
        name: apache-filebeat
        labels:
          app: apache-filebeat
      spec:
        ports:
        - port: 80
        selector:
          app: apache-filebeat
        type: NodePort
      ---
      apiVersion: apps/v1
      kind: Deployment
      metadata:
        name: apache-filebeat
        labels:
          app: apache-filebeat
      spec:
        replicas: 3
        selector:
          matchLabels:
            app: apache-filebeat
        template:
          metadata:
            labels:
              app: apache-filebeat
          spec:
            terminationGracePeriodSeconds: 15
            containers:
            - image: ubuntu/apache2
              name: wl-apache
              volumeMounts:
              - name: varlog
                mountPath: /var/log/apache2
            - image: docker.elastic.co/beats/filebeat:7.14.1
              name: wl-filebeat
              volumeMounts:
              - name: varlog
                mountPath: /var/log/apache2
              - name: filebeat-config
                mountPath: /usr/share/filebeat/filebeat.yml
                subPath: filebeat.yml
            volumes:
            - name: varlog
              emptyDir: {}
            - name: filebeat-config
              configMap:
                name: filebeat-configmap
                items:
                - key: filebeat.yml
                  path: filebeat.yml
     ```

3. 업데이트
   - ```shell
      kubectl patch statefulset es-cluster -n elastic-stack --type='json' -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/image", "value":"docker.elastic.co/elasticsearch/elasticsearch:7.16.1"}]'
      kubectl patch deployment kibana -n elastic-stack --type='json' -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/image", "value":"docker.elastic.co/kibana/kibana:7.16.1"}]'
      kubectl patch deployment apache-filebeat --type='json' -p='[{"op": "replace", "path": "/spec/template/spec/containers/1/image", "value":"docker.elastic.co/beats/filebeat:7.16.1"}]'
     ```
