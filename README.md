# scripts
The scripting provided here is for educational purposes only. There's no support on them neither liability. Use it at your own risk. This is a personal project.

## How to use it

Script get-all-permissions and merge-all-permissions

### Create a custom Role with the following permissions
```
    resourcemanager.folders.get
    resourcemanager.folders.getIamPolicy
    resourcemanager.folders.list
    resourcemanager.organizations.get
    resourcemanager.organizations.getIamPolicy
    resourcemanager.projects.get
    resourcemanager.projects.getIamPolicy
    resourcemanager.projects.list
```

### To execute the script from your workstation

``` 
    gcloud auth login
    gcloud auth application-default login
```
