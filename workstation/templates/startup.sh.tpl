#!/bin/bash
# logging
LOG_FILE=/var/log/startup-script.log
if [ ! -e $LOG_FILE ]
then
     touch $LOG_FILE
     exec &>>$LOG_FILE
else
    #if file exists, exit as only want to run once
    exit
fi

exec 1>$LOG_FILE 2>&1

## variables
repositories="${repositories}"
user="ubuntu"
#tool versions
terraformVersion="${terraformVersion}"
#
set -ex \
&& curl -fsSL https://download.docker.com/linux/ubuntu/gpg |  apt-key add - \
&&  add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
&&  apt-get update -y \
&&  apt-get install -y apt-transport-https wget unzip jq git software-properties-common python3-pip ca-certificates gnupg-agent docker-ce docker-ce-cli containerd.io nginx \
&& echo "docker" \
&&  usermod -aG docker $user \
&&  chown -R $user: /var/run/docker.sock \
&& echo "terraform" \
&&  wget https://releases.hashicorp.com/terraform/$terraformVersion/terraform_"$terraformVersion"_linux_amd64.zip \
&&  unzip ./terraform_"$terraformVersion"_linux_amd64.zip -d /usr/local/bin/ \
&& echo "awscli" \
&&  apt-get install awscli -y \
&& echo "f5 cli" \
&& pip3 install f5-cli \
&& complete -C '/usr/bin/aws_completer' aws \
&& terraform -install-autocomplete \
&& echo "kubectl" \
&& curl -LO "https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl" \
&& chmod +x ./kubectl \
&& sudo mv ./kubectl /usr/local/bin/kubectl \
&& echo 'source <(kubectl completion bash)' >>~/.bashrc \
&& kubectl completion bash >/etc/bash_completion.d/kubectl \
&& echo 'alias k=kubectl' >>~/.bashrc \
&& echo 'complete -F __start_kubectl k' >>~/.bashrc \
&& echo "eksctl" \
&& curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp \
&& sudo mv /tmp/eksctl /usr/local/bin \
&& echo "heml3 binary" \
&& curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 > get_helm.sh \
&& chmod 700 get_helm.sh \
&& ./get_helm.sh \
&& source /usr/share/bash-completion/bash_completion

echo "test tools"
echo '# test tools' >>/home/$user/.bashrc
echo '/bin/bash /testTools.sh' >>/home/$user/.bashrc
cat > /testTools.sh <<EOF
#!/bin/bash
echo "=====Installed Versions====="
terraform -version
f5 --version
aws --version
eksctl version
echo "kubectl:  `kubectl version --short --client`"
echo "hem: `helm version --short`"
echo "=====Installed Versions====="
EOF
echo "clone repositories"
cwd=$(pwd)
ifsDefault=$IFS
IFS=','
cd /home/$user
for repo in $repositories
do
    git clone $repo
    name=$(basename $repo )
    folder=$(basename $name .git)
    chown -R $user $folder
done
IFS=$ifsDefault
echo "=====install coder====="
coderVersion="3.10.1"
curl -sSOL https://github.com/cdr/code-server/releases/download/v$${coderVersion}/code-server_$${coderVersion}_amd64.deb
dpkg -i code-server_$${coderVersion}_amd64.deb
# sudo -u $user curl -fsSL https://code-server.dev/install.sh | sh
mkdir -p /home/$user/.config/code-server
cat > /home/$user/.config/code-server/config.yaml <<EOF
#bind-addr: 127.0.0.1:8080
bind-addr: 0.0.0.0:8080
auth: password
password: ${coderAccountPassword}
cert: false
EOF
chown $user:$user /home/$user/.config/code-server
cat > /lib/systemd/system/code-server.service <<EOF
[Unit]
Description=code-server
[Service]
Type=simple
User=ubuntu
#Environment=PASSWORD=${coderAccountPassword}
ExecStart=/usr/bin/code-server --bind-addr 127.0.0.1:8080 --config /home/$user/.config/code-server/config.yaml --user-data-dir /var/lib/code-server --auth password
#ExecStart=/usr/bin/code-server --bind-addr 127.0.0.1:8080 --auth none
Restart=always
[Install]
WantedBy=multi-user.target
EOF
systemctl enable --now code-server@$user
# install extensions for coder as user
#extensionUrls="https://api.github.com/repos/f5devcentral/vscode-f5/releases/latest https://api.github.com/repos/hashicorp/vscode-terraform/releases/latest"
extensionUrls="https://api.github.com/repos/f5devcentral/vscode-f5/releases/latest https://api.github.com/repos/hashicorp/vscode-terraform/releases/tags/v2.4.0"
for downloadUrl in $extensionUrls
do
    wget $(curl -s $downloadUrl | jq -r '.assets[] | select(.name | contains (".vsix")) | .browser_download_url')
done
extensions=$(ls *vsix)
for extension in $extensions
do
    sudo -u $user code-server --install-extension $extension
    echo $extension
done
# exit user install
su root
rm *.vsix
systemctl restart code-server@$user
# Now visit http://127.0.0.1:8080. Your password is in ~/.config/code-server/config.yaml
cat > /coder.conf <<EOF
server {
    listen 80 default_server;
    server_name _;
    return 301 https://\$host\$request_uri;
}
map \$http_upgrade \$connection_upgrade {
        default upgrade;
        '' close;
    }
server {
    listen       443 ssl;
    server_name  localhost;
    ssl_certificate     /cert/server.crt; # The certificate file
    ssl_certificate_key /cert/server.key; # The private key file
    proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection \$connection_upgrade;
    proxy_set_header Host \$host;
    location / {
        proxy_pass http://127.0.0.1:8080;
    }
    error_page   500 502 503 504  /50x.html;
    location = /50x.html {
        root   /usr/share/nginx/html;
    }
}
EOF
echo "====self signed cert===="
mkdir -p /cert
cd /cert
openssl genrsa -des3 -passout pass:1234 -out server.pass.key 2048
openssl rsa -passin pass:1234 -in server.pass.key -out server.key
rm server.pass.key
openssl req -new -key server.key -out server.csr -subj "/C=US/ST=testville/L=testerton/O=Test testing/OU=Test Department/CN=test.example.com"
openssl x509 -req -sha256 -days 365 -in server.csr -signkey server.key -out server.crt
echo "=====start nginx====="
docker run --network="host" --restart always --name nginx-coder -v /coder.conf:/etc/nginx/conf.d/default.conf -v /cert:/cert -p 443:443 -p 80:80 -d nginx
echo "=====done====="
exit
