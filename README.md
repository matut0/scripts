# Disclaimer
The scripting provided here is for educational purposes only. There's no support on them neither liability. Use it at your own risk. This is a personal project.

# Get all Google cloud permission assigned to an entity

This scripts will get all the permissions recursively from organization all way down to the folders / sub folder and projects using as input the file user_lists.txt

## How to use it

For using the scripts, you need to change the ```ORG_ID``` variable defined in ```get-all-permissions-v3.0.sh``` and ```merge-all-permissions-v2.0.sh``` 
and also have a list of users to get the iam info from, the file user_list.txt.

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
