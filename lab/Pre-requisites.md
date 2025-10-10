# Prerequisite Steps for a Super User
    - Must have Owner or Contributor level permissions on the subscription.
    - Must have Account Admin level permissions on Azure Databricks.
    - Ensure that the subscription has a minimum of 50 vCPU cores available to support the Databricks cluster deployment.
    - Ensure that the Parent and child deployments are created in the same region to avoid configuration conflicts and ensure proper resource connectivity.


## Create a Parent Azure Databricks Service.

1. **Open** the Azure Portal by clicking on the button below.

<a href='https://portal.azure.com/' target='_blank'><img src='http://azuredeploy.net/deploybutton.png' /></a>

2. In the Azure portal, select the **Terminal icon** to open Azure Cloud Shell.

    ![A portion of the Azure Portal taskbar is displayed with the Azure Cloud Shell icon highlighted.](../img/cloud-shell.png)

3. **Click** on **PowerShell**.

    ![](../img/cloud-shell-12.png)
   

5. Select the **Subscription** and click on **Apply**.

    ![Mount a Storage for running the Cloud Shell.](../img/cloud-shell-2.1.png)

    > **Note:** If you already have a storage mounted for Cloud Shell, you will not get this prompt. In that case, skip step 5 and 6.


6. In the Azure Cloud Shell window, ensure that the **PowerShell** environment is selected.

    ![Git Clone Command to Pull Down the demo Repository.](../img/cloud-shell-3.1.png)

    >**Note:** All the cmdlets used in the script work best in PowerShell .	

    >**Note:** Use 'Ctrl+C' to copy and 'Shift+Insert' to paste, as 'Ctrl+V' is NOT supported by Cloud Shell.

7. Enter the following command to clone the repository files in Cloud Shell.

Command:

```
git clone -b ignite25-LAB535 --single-branch https://daidemos@dev.azure.com/daidemos/DREAMDemos/_git/DREAMPoC
```


   ![Git Clone Command to Pull Down the demo Repository.](../img/cloud-shell-4.5.png)
    
   > **Note:** If you get File already exist error, please execute the following command to delete existing clone and then re-clone:
```
 rm DREAMPOC -r -f 
```
   > **Note**: When executing scripts, it is important to let them run to completion. Some tasks may take longer than others to run. When a script completes execution, you will be returned to a command prompt. 

7. **Execute** the PowerShell script with the following command:
```
cd ./DREAMPOC
```

```
./databricksWorkspaceWithCatalog.ps1
```
    
   ![Commands to run the PowerShell Script.](../img/cloud-shell-5.1.png)

8. **Press** **Y** and click on the **Enter** button.
      
![Yes.](../img/yes.png)

9. From the Azure Cloud Shell, **copy** the authentication code. You will need to enter the code in the next step.

10. **Click** the link [https://microsoft.com/devicelogin](https://microsoft.com/devicelogin) and a new browser window will launch.

![Authentication link and Device Code.](../img/cloud-shell-10.png)
     
11. **Paste** the authentication code.

    ![box](../img/cloud-shell-7.png) 

12. **Select** the user account you used for logging into the Azure Portal in [Task 1](#task-1-create-a-resource-group-in-azure).

![box](../img/cloud-shell-8.png) 

13. **Click** on the **Continue** button.

![box](../img/cloud-shell-8.1.png) 

14. **Close** the browser tab when you see the message box.

    ![box](../img/cloud-shell-9.png)   

15. **Navigate back** to your **Azure Cloud Shell** execution window.

16. **Copy** your subscription name from the screen and **paste** it in the prompt.

    ![Close the browser tab.](../img/select-sub1.png)
    
    > **Notes:**
    > - Users with a single subscription won't be prompted to select a subscription.
    > - The subscription highlighted in Light blue will be selected by default, if you do not enter a desired subscription. Please select the subscription carefully as it may break the execution further.
    > - While you are waiting for the processes to complete in the Azure Cloud Shell window, you'll be asked to enter the code three times. This is necessary for performing the installation of various Azure Services and preloading the data.

17. **Copy** the code on the screen to authenticate the Azure PowerShell script for creating reports in Power BI. **Click** the link [https://microsoft.com/devicelogin](https://microsoft.com/devicelogin).

    ![Authentication link and Device code.](../img/cloud-shell-10.png)

18. A new browser window will launch. **Paste** the authentication code you copied from the shell above.

    ![box](../img/cloud-shell-11.png) 

19. **Select** the user account that is used for logging into the Azure Portal in [Task 1](#task-1-create-a-resource-group-in-azure).

    ![Select Same User to Authenticate.](../img/cloud-shell-12.png)

20. **Click** on 'Continue'.

    ![box](../img/cloud-shell-12.1.png) 

21. **Close** the browser tab when you see the message box.

    ![box](../img/cloud-shell-13.png) 

22. **Go back** to the Azure Cloud Shell execution window.

23. **Enter** the Region for deployment with the necessary resources available, preferably "eastus". 
    (Ex.: eastus, eastus2, westus, westus2, etc).

    ![box](../img/cloudshell-region.png)


# Post deployment steps

## Enable Entra ID Sync

1. Go to https://accounts.azuredatabricks.net/ and **Settings** in Databricks UI.
2. Go to **User provisioning** tab.
3. Toggle on **Automatic identity management** to "Enabled".
    - This will sync users and groups from Microsoft Entra ID (Azure AD) for seamless management.

![](../img/databricks00.png)


## Add Workspaces to Metastore

1. Go to https://accounts.azuredatabricks.net/ and **Catalog > Metastores** in Databricks UI.
2. Locate your metastore created for Lab (e.g., `metastore-westus2`).
3. Click the metastore's name to manage it.
4. Find the option to add or link **Workspaces** to this metastore.
5. Select the **Child** Databricks workspaces created for Lab where you want Unity Catalog available and confirm linkage.

![](../img/p2.png)

![](../img/p2.1.png)

## Run Notebook Script to Add Users to Unity Catalog

1. Open a Databricks notebook and set the language to **Python** or **PySpark**.

![](../img/databricks01.png)

2. Insert and run the following script (Update all Lab user E-mails):

```
# Set variables for catalog and users
catalog = "your_unity_catalog"
users = [
    "user1@cloudlabsaioutlook.onmicrosoft.com",
    "user2@cloudlabsaioutlook.onmicrosoft.com",
    "user3@cloudlabsaioutlook.onmicrosoft.com"
]
privileges = ["USE CATALOG", "CREATE", "ALL PRIVILEGES"]

# Loop and grant permissions for each user
for user in users:
    for privilege in privileges:
        query = f"GRANT {privilege} ON CATALOG `{catalog}` TO `{user}`"
        spark.sql(query)

```


![](../img/p3.png)

