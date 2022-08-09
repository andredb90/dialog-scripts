# swiftDialog + FileWave

- [swiftDialog](https://github.com/bartreardon/swiftDialog) Script with FileWave integration
- Download, install and configuration
- Use `--filewave` to parse fwcld.log and provide useful information during deployment
- Use `--ms365` to install the latest version of Microsoft Office 365 Apps directly from Microsoft. 

Please be aware that FileWave environments and deployment strategies can be very different. What works for me doesn't necessarily work for you.
As always: Test, test, test!

Based on:
Adam Codega (@adamcodega)'s [MDMAppsDeploy](https://github.com/acodega/dialog-scripts/blob/main/MDMAppsDeploy.sh) and [officeinstallProgress](https://github.com/acodega/dialog-scripts/blob/main/officeInstallProgress.sh). 

Check out Adam's repository for other useful dialog scritps: https://github.com/acodega/dialog-scripts

When using the `--ms365` argument, the script will automatically add Microsoft Office 365 to the top of the list and show progress for the installation.
This is escpecially useful during the initial enrollment, because it allows us to install the Microsoft Office Suite while FileWave is still downloading associated FileSets. 
The script will continue looking for additional datapoints from the list and mark them as complete accordingly. 
<img width="932" alt="Screenshot 2022-08-07 at 13 29 41" src="https://user-images.githubusercontent.com/8020217/183288535-e66c1cc5-5eb9-4d37-bb4c-4695e95421ce.png">
<img width="932" alt="Screenshot 2022-08-07 at 13 30 11" src="https://user-images.githubusercontent.com/8020217/183288542-843278bd-93ce-42cc-b9bc-e6e3c0ee657d.png">
<img width="932" alt="Screenshot 2022-08-07 at 13 32 26" src="https://user-images.githubusercontent.com/8020217/183288543-7c6fe653-df95-478b-9243-19e806321cdf.png">
<img width="932" alt="Screenshot 2022-08-07 at 13 33 13" src="https://user-images.githubusercontent.com/8020217/183288548-754c0d9c-9124-4ba6-a0e9-bd2d967d10f3.png">

Use `--filewave` argument to display information during FileSet deployments.

<img width="932" alt="Screenshot 2022-08-07 at 20 51 53" src="https://user-images.githubusercontent.com/8020217/183306615-fd162e92-e668-4320-ba44-5f86fb58a9e7.png">


Use `--filewave-progress in combination with filewave-dialog-progress.sh to automatically show downlading progress and add installer packages to the list.


https://user-images.githubusercontent.com/8020217/183651789-1ab0f410-17cc-41b1-a07f-8a46926158e6.mov

