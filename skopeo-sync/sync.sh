#!/usr/bin/env bash

cat > /etc/skopeo-images.yaml <<EOF
k8s.gcr.io:
  images:
    pause:
      - 3.1
      - 3.2
    kube-apiserver:
      - v1.18.3
      - v1.18.4
      - v1.18.5
    kube-controller-manager:
      - v1.18.3
      - v1.18.4
      - v1.18.5
    kube-scheduler:
      - v1.18.3
      - v1.18.4
      - v1.18.5
    kube-proxy:
      - v1.18.3
      - v1.18.4
      - v1.18.5
    etcd:
      - 3.4.3-0
      - 3.4.7-0
    coredns:
      - 1.6.7
EOF

exec skopeo --insecure-policy sync --src yaml --dest docker /etc/skopeo-images.yaml "$TO"
