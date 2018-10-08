# MMDialogPopup
A UIViewController to easily show dialog popups in iOS

![](MMDialogPopupDemo.gif)

## Usage

#### Download the MMDialogPopupViewController.swift file and put it inside your project
Download the file, and put it somewhere appropriate in your project.

#### Showing a DialogPopup
Create an instance of MMDialogPopViewController, and then pass in your view controller (The one you want to show as a popup),
and then call `.show(onViewController:)` on it. 

```
let dialogPopup = MMDialogPopupViewController(contentViewControler: yourViewController)
dialogPopup.show(onViewController: self)
```

## Author
Mario Amgad Mouris, marioamgad9@gmail.com

## Disclaimer
This view controller is heavily influnced by [Steve Barnegren's](https://github.com/SteveBarnegren/SBCardPopup) one 
