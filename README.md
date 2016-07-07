# devhttps

HTTPS proxy for emulating secure connections in development.

## Usage

```
# grab npm by installing node.js
npm install -g devhttps

devhttps 1443 80
# then map your localhost:443 to your localhost:1443

# or directly..
sudo devhttps 443 80
```

## How to let the Chrome display the green lock

First time you run `devhttps`, it will generate the CA certificate (with its private key) under `./.devhttps.ca.crt`. Import it and mark it trusted then restart your browser.

![screen shot 2016-07-08 at 10 21 44 am](https://cloud.githubusercontent.com/assets/1559832/16671823/e26c26a4-44f5-11e6-8edb-a06bbf9b0d8e.png)

Keep the private key safe!
