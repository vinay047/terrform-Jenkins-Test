pipeline { 
   agent any 
 
   parameters{ 
          string(name: 'ECS_CLUSTER_NAME', 
          defaultValue: 'terraform-eks-demo', 
          description: 'ECS_CLUSTER_NAME') 
 
          string(name: 'JUMP_SERVER_IP', 
          defaultValue: '52.23.168.124', 
          description: 'JUMP_SERVER_IP') 
 
          string(name: 'JENKINS_ACCESS_KEY_ID', 
          defaultValue: 'access_key', 
          description: 'JENKINS_ACCESS_KEY_ID') 
 
          password(name: 'JENKINS_SECRET_ACCESS_KEY', 
          defaultValue: 'secret_key', 
          description: 'JENKINS_SECRET_ACCESS_KEY') 
 
          string(name: 'DEFAULT_REGION', 
          defaultValue: 'deault_region', 
          description: 'DEFAULT_REGION') 
       } 
    
   stages { 
 
    stage('Checkout') { 
         steps { 
        git 'https://git-codecommit.us-east-1.amazonaws.com/v1/repos/Agent_Landing_Portal' 
 
        } 
       } 
 
      stage('Create and push image to ECR') { 
 
 
         steps { 
            sh 'aws configure set aws_access_key_id ${JENKINS_ACCESS_KEY_ID}' 
            sh 'aws configure set aws_secret_access_key ${JENKINS_SECRET_ACCESS_KEY}' 
            sh 'aws configure set default.region ${DEFAULT_REGION}' 
            sh 'sudo `aws ecr get-login --no-include-email`' 
            sh 'sudo docker build -t 530817571331.dkr.ecr.us-east-1.amazonaws.com/docker-image:vinaylatest .' 
            sh 'sudo docker push 530817571331.dkr.ecr.us-east-1.amazonaws.com/docker-image:vinaylatest' 
 
         } 
 
      } 
 
      stage('Deploy to K8s') { 
 
                       steps { 
 
                          sshagent(['jenkins']){ 
                            sh "scp -o StrictHostKeyChecking=no pods.yml services.yml  ec2-user@${JUMP_SERVER_IP}:/home/ec2-user/" 
                            script { 
                                try{ 
                                sh 'rm -rf  ~/.aws/credentials' 
                                sh 'rm -rf  ~/.aws/config' 
                                sh 'aws configure set aws_access_key_id ${JENKINS_ACCESS_KEY_ID}' 
                                sh 'aws configure set aws_secret_access_key ${JENKINS_SECRET_ACCESS_KEY}' 
                                sh 'aws configure set default.region ${DEFAULT_REGION}' 
                                sh 'ssh ec2-user@${JUMP_SERVER_IP} aws eks --region us-east-1 update-kubeconfig --name ${ECS_CLUSTER_NAME}' 
                                sh 'ssh ec2-user@${JUMP_SERVER_IP} ls -latr' 
                                sh 'ssh ec2-user@${JUMP_SERVER_IP} kubectl apply -f .' 
                                }catch(error){ 
                                    sh 'ssh ec2-user@${JUMP_SERVER_IP} kubectl create -f .' 
                                } 
                            } 
                          } 
 
                       } 
            } 
 
  } 
 
} 
