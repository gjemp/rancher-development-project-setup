# rancher-development-project-setup-
This setup is useful when there is provisioned empty Rancher Proejct 

* it can create <env> or <env>-<team> pattern namespaces , depends what is defined in the script
  * so it can be used as base setup creation for a single team Rancher project  or one Rancher project with multiple teams
* it can create Banzai Cloud logging resources for each namespace  ( Flow , Output and secret )
* it will create team based kustomization.yaml with all created resoruces definition
* by default --dry-run=client is enabled to avoid common sense mistakes  :slightly_smiling_face:

  
# How to run

just run it from ur machine or from the Rancher kubectl shell
 
./deploy.sh 
