openssl genrsa -out john.key 2048
openssl req -new -key john.key -out john.csr -subj "/CN=john/O=boanproject"
sudo openssl x509 -req -in john.csr -CA /etc/kubernetes/pki/ca.crt -CAkey /etc/kubernetes/pki/ca.key -CAcreateserial -out john.crt -days 365
rm john.csr
kubectl config set-credentials john --client-certificate=john.crt  --client-key=john.key
kubectl config set-context john@kubernetes --cluster=kubernetes --namespace=dev1 --user=john

