# Security

## Security Context
- `spec.securityContext`에서 정의
  - `runAsUser: <uid>`
  - `runAsGroup: <gid>`
  - `fsGroup: <id>` 아래 예제의 경우 `data/demo` 디렉토리만 파드에서 읽기/쓰기 가능하게 2000 id의 Group으로 소유 설정됨
  - ```yaml
    apiVersion: v1
    kind: Pod
    metadata:
      name: security-context-demo
    spec:
      securityContext:
        runAsUser: 1000
        runAsGroup: 3000
        fsGrouP: 2000
      volumes:
      - name: sec-ctx-vol
        emptyDir: {}
      containers:
      - name: sec-ctx-demo
        image: busybox
        command: [ "sh", "-c", "sleep 1h" ]
        volumeMounts:
        - name: sec-ctx-vol
          mountPath: /data/demo
        securityContext:
          allowPrivilegeEscalation: false
    ```
  - allowPrivilegeEscalation ?
  - `spec.containers.securityContext` 에서 개별 컨테이너의 Security Context 설정 가능 (`spec.securityContext`의 값 override) 
- capabilities
  - 커널의 기능 추가
  - 컨테이너 내부에서 `cat /proc/1/status`로 확인 가능  
    ```yaml
    apiVersion: v1
    kind: Pod
    metadata:
      name: security-context-demo-3
    spec:
      containers:
      - name: sec-ctx-3
        image: gcr.io/google-samples/node-hello:1.0
    ```  
    ```console
      ...
      CapPrm:	00000000a80425fb
      CapEff:	00000000a80425fb
      ...
    ```  
    ```yaml
      apiVersion: v1
      kind: Pod
      metadata:
        name: security-context-demo-4
      spec:
        containers:
        - name: sec-ctx-4
          image: gcr.io/google-samples/node-hello:1.0
          securityContext:
            capabilities:
              add: ["NET_ADMIN", "SYS_TIME"]
    ```
    ```console
      ...
      CapPrm:	00000000aa0435fb
      CapEff:	00000000aa0435fb
      ...
    ```
    리틀 엔디안 비트 순서이기 때문에 뒤에서 부터 0번째 기능부터 비트맵 시작 (CAP_NET_ADMIN은 12, CAP_SYS_TIME은 25)
