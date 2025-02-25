@{
    Name = 'Hello World with JQueryUI'
    PSTypeName = 'http://shouldbeonschema.org/Topic'
    Content = (
                    ConvertFrom-Markdown @"
Setting up a simple page is usually anything but.
For every few lines of content, there are a dozen of tags.
Let's see how we can make a nice hello world page without breaking a sweat:
"@
                ) + (
                Write-ScriptHTML @'
New-Region -aspopout -Layer @{
    "Hello World" = "Welcome to PowerShell Pipeworks.  It's time to Update-Web -with Powershell."
}-Style @{
    "top" = "10%"
    "margin-left" = "17%"
    "margin-right" = "17%"
    "text-align" = "center"
    "font-size" = "xx-large"            
} |
    New-WebPage -Title "Hello World" -UseJQueryUI -JQueryUITheme Blitzer                
'@)

} 
 
