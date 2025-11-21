# Easy GUI PowerShell Module

## About EasyGUI:

Easy GUI PowerShell Module Allows you to create a GUI Easily in PowerShell

## How to Install And Use?
#### To Install it You will have to use 
```
Install-Module EasyGUI
```

``If that doesn't work you can use:``
```
Install-Module EasyGUI -Force
```

#### Example Code:

```
Import-Module "EasyGUI"
if (PrepareWindow -Title "Example GUI Title" -Width 400 -Height 400) {
            Window.AddTabControl

        Window.AddTab -Label "Tab 1" {
            Window.Text "Example Text"
            Window.AddButton "Example Button" -Command {
            Write-Host "You Clicked Me!" -foreground Green
            }
            }
        Window.AddTab -Label "Tab 2" {
          Window.Text "Tab 2"
        }
    }
```

