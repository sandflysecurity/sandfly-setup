This is a holding area for setup data for Sandfly.

The Server should contain the following files under this directory:

admin.password.txt (Only used during DB init with random password. Invalid once user logs in and changes it.)
api.node.password.txt
api.server.hostname.txt
cacert.b64
dhparam.b64
elastic.server.hostname.txt
fernet.password.b64
login.screen.password.txt (OPTIONAL)
node.pub.asc.b64
node_cert.b64
node_key.b64
rabbit.admin.password.txt
rabbit.node.password.txt
rabbit.server.hostname.txt
rabbit_cert.b64
rabbit_key.b64
secrets.txt
server_cert.b64
server_key.b64
server_key_signed.b64 (OPTIONAL if SSL signed cert is used)
server_cert_signed.b64 (OPTIONAL if SSL signed cert is used)

The Node should only have these files present:

api.node.password.txt
api.server.hostname.txt
cacert.b64
node.sec.asc.b64 (Node secret key should ONLY be on nodes and not on the server instance!)
node_cert.b64
node_key.b64
rabbit.node.password.txt
rabbit.server.hostname.txt


