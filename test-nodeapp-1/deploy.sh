#!/bin/bash
docker system prune
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 417139048224.dkr.ecr.us-east-1.amazonaws.com
docker pull 417139048224.dkr.ecr.us-east-1.amazonaws.com/ashwin-bharadwaj-c4-p1:latest
(docker ps -a --format {{.Names}} | grep c4-project -w) && docker rm -f c4-project || echo "c4-project not present"
docker run -itd -p 8080:8081 --name=c4-project 417139048224.dkr.ecr.us-east-1.amazonaws.com/ashwin-bharadwaj-c4-p1:latest
