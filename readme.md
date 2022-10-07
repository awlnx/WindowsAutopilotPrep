# Autopilot Image Prep

On non-autopilot machines the push button reset mechanism built-in to windows isn't always reliable. 
This project is to create an easy to make, easy to use custom image iso for use in getting machines imaged and ready for autopilot.
Place your Isos in the windows folder, any critical drivers you may need for any of your machines in the drivers folder and run the CreateCustomIso.ps1 script. This script will connect to your tenant and grab your autopilot profile (or select No Profile if you intent to upload the hashes and just want a usb imaging tool), patch drivers into the boot, install, and recovery wims, and create an ISO you can use with [Rufus](https://rufus.ie/en/)