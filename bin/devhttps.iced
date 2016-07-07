async = require 'async'
fs = require 'fs'
https = require 'https'
http = require 'http'
pem = require 'pem'
tls = require 'tls'
s = require 'underscore.string'
config = {
  certs: {}
}

unless config.ca_key && config.ca_crt
  console.log '[ca] loading...'
  await fs.readFile '.devhttps.ca.key', defer e, config.ca_key
  await fs.readFile '.devhttps.ca.crt', defer e, config.ca_crt
unless config.ca_key && config.ca_crt
  console.log '[ca] generating key...'
  await pem.createPrivateKey defer e, { key }
  throw e if e
  console.log '[ca] generating request...'
  await pem.createCSR
    clientKey: key
    commonName: 'Development Certificate Authority for devhttps'
  , defer e, { csr }
  throw e if e
  config.ca_key = key
  console.log '[ca] generating certificate...'
  await pem.createCertificate
    clientKey: key
    csr: csr
    selfSigned: true
    days: 1800
  , defer e, { certificate }
  throw e if e
  config.ca_crt = certificate
  await fs.writeFile '.devhttps.ca.key', config.ca_key, defer e
  if e
    console.log e.message
  else
    console.log '[ca] private key saved to .devhttps.ca.key'

  await fs.writeFile '.devhttps.ca.crt', config.ca_crt, defer e
  if e
    console.log e.message
  else
    console.log '[ca] certificate saved to .devhttps.ca.crt'

ms_day = 3600 * 24
cert_expiry_days = 60
transform_headers = (raw_headers)=>
  headers = {}
  for k, v of raw_headers
    k = k.replace /\w+\W*/g, (match)->
      s(match).titleize().value()
    headers[k] = v
  headers
server = https.createServer
  SNICallback: (domain, cb)->
    domain = domain.toLowerCase()
    if config.certs[domain] && Date.now() - config.certs[domain].created_at > ms_day * (cert_expiry_days - 1)
      console.log "[#{domain}] certicate expired."
      delete config.certs[domain]
    unless config.certs[domain]
      console.log "[#{domain}] generating key..."
      await pem.createPrivateKey defer e, { key }
      throw e if e
      console.log "[#{domain}] generating request..."
      await pem.createCSR
        clientKey: key
        commonName: domain
      , defer e, { csr }
      throw e if e
      console.log "[#{domain}] signing request..."
      await pem.createCertificate
        serviceKey: config.ca_key
        serviceCertificate: config.ca_crt
        serial: Date.now()
        csr: csr
        days: cert_expiry_days
      , defer e, { certificate }
      throw e if e
      crt = certificate
      config.certs[domain] =
        crt: crt
        key: key
        created_at: Date.now()
    await setTimeout defer(), 5000
    credentials = tls.createSecureContext
      cert: config.certs[domain].crt
      key: config.certs[domain].key
      ca: [config.ca_crt]
    cb null, credentials.context
  , (req, res)->
    console.log "[#{req.headers.host}] client request #{req.method} #{req.url}"
    req.headers['X_FORWARDED_PROTO'] = 'https'
    headers = transform_headers req.headers
    proxy_req = http.request
      hostname: 'localhost'
      port: http_port
      method: req.method
      path: req.url
      headers: headers
    , (proxy_res)->
      console.log "[#{req.headers.host}] server response #{proxy_res.statusCode} #{proxy_res.statusMessage}"
      delete proxy_res.headers['connection']
      res.writeHead proxy_res.statusCode, proxy_res.statusMessage, transform_headers proxy_res.headers
      proxy_res.pipe res
      proxy_res.resume()
    req.pipe proxy_req
    req.resume()
    

https_port = Number process.argv[2]
http_port = Number process.argv[3]
https_bind = process.argv[4] || 'localhost'

unless !isNaN(https_port) && !isNaN(http_port) && https_port && http_port
  throw new Error "Usage: devhttps HTTPSPORT HTTPPORT or devhttps HTTPSPORT HTTPPORT HTTPSBIND"
server.listen https_port, https_bind, ->
  console.log "https://#{https_bind}:#{https_port} => http://#{https_bind}:#{http_port}"




