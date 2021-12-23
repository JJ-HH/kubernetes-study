# 웹로그 수집을 위한 파이프 라인 구축

## Obejctive
### EK 7.14.1 배포
- [ ] Deploy ElasticSearch StatefulSet
  - [ ] EK stack을 위한 namespace 생성
  - [ ] ElasticSearch statefulset 생성
  - [ ] ElasticSearch headless service 생성
- [ ] Deploy Kibana
  - [ ] NodePort service + Deployment 생성

### Nginx + FileBeat 배포
- [ ] 웹 + access log 사이드카 + error log 사이드카 as deployment
  - [ ] 멀티컨테이너 Emptydir로 로그 공유
  - [ ] access.log
  - [ ] error.log
- [ ] 키바나에서 로그전달 확인
  
### EK 7.16.2 업데이트
- [ ] ElasticSearch RollingUpdate
  - [ ] index 스냅샷 생성
  - ElasticSearch 업그레이드
  - Kibana 업그레이드
  - FileBeat 업그레이드
  
