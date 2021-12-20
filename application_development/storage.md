# Volumes
## emptyDir
  - 파드 안의 여러 컨테이너가 공유할 수 있는 임시 볼륨
## hostPath
  > mounts a file or directory from the host node's filesystem into your Pod
  - 파드가 실행중인 노드의 파일시스템을 사용
  - 마스터노드의 핵심 컴포넌트들이 주로 사용 (kube-apiserver, kube-scheduler, etcd, ...)
  - 모니터링을 위한 용도 (/var/log/)
  ```yaml
    ...
    spec:
    containers:
      ...
      volumeMounts:
      - mountPath: /var/local/aaa
        name: mydir
      - mountPath: /var/local/aaa/1.txt
        name: myfile
    volumes:
    - name: mydir
      hostPath:
        # Ensure the file directory is created.
        path: /var/local/aaa
        type: DirectoryOrCreate
    - name: myfile
      hostPath:
        path: /var/local/aaa/1.txt
        type: FileOrCreate
  ```
## local
  > represents a mounted local storage device such as a disk, partition or directory
  > can only be used as a statically created PersistentVolume. Dynamic provisioning is not supported.
  - 마운트된 디스크의 
  ```yaml
    ...
    spec:
      capacity:
        storage: 100Gi
      volumeMode: Filesystem
      accessModes:
      - ReadWriteOnce
      persistentVolumeReclaimPolicy: Delete
      storageClassName: local-storage
      local:
        path: /mnt/disks/ssd1
      nodeAffinity:
        required:
          nodeSelectorTerms:
          - matchExpressions:
            - key: kubernetes.io/hostname
              operator: In
              values:
              - example-node
  ```
  
## Mounting ConfigMaps
> ConfigMap is an API object used to store non-confidential data in key-value pairs. Pods can consume ConfigMaps as environment variables, command-line arguments, or as __*configuration files in a volume*__.
- coreDNS
- .conf 파일로 `data:`부분을 파일시스템 등록 후 부팅 시점에 mount해서 사용
```kubernetes
kubectl apply -f example-redis-config.yaml
wget https://raw.githubusercontent.com/kubernetes/website/main/content/en/examples/pods/config/redis-pod.yaml
kubectl apply -f redis-pod.yaml
kubectl exec -it redis -- redis-cli
CONFIG GET maxmemory-policy
```

## Mounting Secrets
- SA(:Service Account)에 권한을 전달
  - SA 생성시 secret이 자동으로 구성
  - 토큰을 Mount해서 secret 사용
