# devspoon-startup-web

devspoon-startup-web is an integrated management solution that allows you to easily build the solutions needed for startups (openproject, jenkins, gitolite [private git server], Harbor [private Docker server]).
A single docker-compose can be used to install various development, backup, and management services singly, in groups, or collectively.
This repository is based on the [devspoon-web](https://github.com/devspoons/devspoon-web) project. devspoon-web is an open source that allows you to easily build a web or API based on php, python, django, nginx, and redis using docker-compose.

# introduce "Devspoon-Projects"

- We provide an open source infrastructure integration solution that can easily service Python, Django, PHP, etc. using docker-compose. You can install the commercial-level customizable nginx service and redis at once, and install and manage more services at once. If you are interested, please visit [Devspoon-Projects](https://github.com/devspoon/Devspoon-Projects).

# Official guide document

- preparing...

## Project management solutions

- **[OpenProject]** : Open source project management software to help you work on your project efficiently

- **[Jenkins]** : As one of the CI tools, CI (Continuous Integration) refers to continuous integration, which is an automated process for developers, and new code changes are automatically built and tested regularly to notify developers to solve problems that can occur when multiple developers develop simultaneously. Software that helps secure development stability and reliability

- **[Gitolite]** : Configuration Management Tool. user can install git server software at own server

- **[Harbor]** : The Private Docker Registry Server for businesses that store and distribute Docker Images

## Features

- **Supports creation of configuration files required for each service** : Environment files and security keys used for each service are created according to the user's keyboard input using a shell script or automatically generated.

- **User custom installation support** : You can selectively install only the desired solution at compose/project_mng_service/(solution) without having to install all the solutions.

  - To install more than one solution at the same time, use the docker-compose file located in the "compose/master_service/" folder.

  - How to use: docker-compose -f docker-compose-php.yml up -d

  - How to use (celery): docker-compose -f docker-compose-php.yml --profile celery up -d

  - How to use (redis): docker-compose -f docker-compose-php.yml --profile redis up -d

  - How to use (all): docker-compose -f docker-compose-php.yml --profile celery --profile redis up -d

- **Access web server and project management solutions with one nginx through nginx proxy** : All solutions are available on one nginx server.

  ```
  Example

  test.com -> company website
  blog.test.com -> blog website
  shop.test/com -> shopping mall website
  open.test.com -> openproject solution
  jen.test.com -> jenkins solution
  ```

- **etc** :

  - You can use ssh for direct access to gitolite.
  - The harbor will be supported in a future version due to security issues, and you can connect to your own server through harbor.yml.

## considerations

- **Development-oriented docker service** : This open source is perfect for startups or new service development teams that require frequent modifications and testing.

- **this open-source considers generic servers that are not support AWS, GCM** : This open source is intended to be installed and operated on a server that is directly operated, and on general server hosting, and plans to integrate with cloud services such as AWS and GCM in the future

## Install & Run

### OpenProject

1. When using OpenProject, e-mail account information is required to send events by e-mail

- [mailgun] service setting

  - It is recommended to use [sendgrid] as the rate policy change

  ```
  Information on the following items should be updated by referring to the comments in the docker-compose.yml file in the compose/project_mng_service/nginx_openproject folder

  environment:
        EMAIL_DELIVERY_METHOD: smtp
        SMTP_ADDRESS: smtp.mailgun.org #Need to change when using other services than mailgun
        SMTP_PORT: 587 #Need to change when using other services than mailgun
        SMTP_DOMAIN: "test.com" #user's SMTP domain information
        SMTP_AUTHENTICATION: login
        SMTP_ENABLE_STARTTLS_AUTO: "true"
        SMTP_USER_NAME: "test@test.com" #Service account information
        SMTP_PASSWORD: "1234567890067655abcdefgh" #Service authentication key information
  ```

2. Run nginx_proxy_conf.sh file in config/web-server/(web server type) and enter service port number, domain, proxy url(Openproject's application name in docker-compose.yml), proxy port number, filename, and than, it make a nginx conf file in conf.d folder

3. Run docker-compose.yml (single mode)

   ```
   get move to compose/project_mng_service/nginx_openproject
   Execute docker-compose.yml using "docker-compose up -d" command
   ```

4. There are advanced information in [OpenProject Official User Documentation](https://docs.openproject.org/installation-and-operations/operation/backing-up/)

---

### Jenkins

1. Run nginx_proxy_conf.sh file in config/web-server/(web server type) and enter service port number, domain, proxy url(Openproject's application name in docker-compose.yml), proxy port number, filename, and than, it make a nginx conf file in conf.d folder

2. Run docker-compose.yml (single mode)

   ```
   get move to compose/project_mng_service/nginx_jenkins
   Execute docker-compose.yml using "docker-compose up -d" command
   ```

3. There are advanced information in [Jenkins Official User Documentation](https://www.jenkins.io/doc/)

---

### Gitolite

1. This docker make 2 account as gitolite-creator and git-manager. gitolite install at gitolite-creator and git-manager will manage gitolite system such as add new user or make new repogitory etc

2. For management add new user account or make new repository, administrator must be accessed gitolite server by git-manager account. So, User must make client_user.pub key in docker/gitolite/system folder. Dockerfile will add this key at authorized_keys in git-manager account

3. Run docker-compose.yml (single mode)

   ```
   get move to compose/project_mng_service/gitolite
   current ssh port number is 2222. if user want to change the ssh port number, modify in docker-compose.yml
   Execute docker-compose.yml using "docker-compose up -d" command
   ```

4. There are sample code

   - /home/git-manager/sample-script in the container

   ```
   clone_admin.sh -> clone admin repository to manage gitolite system. administrator must manage gitolite system though only git-manager account
   add_user.sh -> it show how to add new user in gitolite
   ```

5. There are advanced information in [Gitolite Cookbook](https://gitolite.com/gitolite/cookbook)

---

### Harbor

1. To use harbor, it require latest docker-compose package. run /compose/project_mng_service/harbor-v.2.0.0/update_docker-compose.sh. if user already have latest version than 1.26.0, don't need this step

2. harbor require a configuration file such as harbor.yml. update_harbor_config.sh file make harbor.yml. and then run install.sh, harbor will install successfully

3. If user want to install harbor by one step, user can use autoinstall.sh file. it is process to make harbor.yml and run install.sh.

4. If user want to use https, have to make ssl key in /compose/project_mng_service/harbor-v.2.0.0/ssl/ before runing install.sh or autoinstall.sh.

5. If user want to make ssl key, refer "Setting up HTTPS on a web server" section. there are at bottom in this page

6. There are advanced information in [Harbor 2.0 Documentation](https://goharbor.io/docs/2.0.0/)

## Setting up HTTPS on a web server

- This step requires running http nginx server. it recommend php nginx server for this step. if user need to informations for this, refer to [devspoon-web]

  ```
  1. There are letsencrypt.sh shell script file in script folder and it interlocked by volumes.
  so user can access script file in a nginx container.

  2. use "docker exec -it <nginx container name> bash" command, user can get docker inside.

  3. run letsencrypt.sh and insert informations such as webroot, domain, e-mail etc.
      this script make ssl-key and make crontab schedule automatically

  4. using "exit" command user can get off from container

  5. Run nginx_proxy_https_conf.sh file in config/web-server/(web server type) and enter service port number, domain, proxy url(Openproject's application name in docker-compose.yml), proxy port number, filename, and than, it make a nginx conf file in conf.d folder

  6. user have to remove http conf file in config/web-server/<service>/conf.d/

  7. run "docker-compose up" command in the compose folder
  ```

## Additional development item

- System integration between jenkins, gitolite, openproject.
- Support docker-swarm, kubernetes
- docker and orchestration monitoring system
- backup and security system
- Support cloud such as AWS, GCM etc

## Community

- **Personal Website** : Owner's personal website is [devspoon.com](devspoon.com)

## Partners and Users

- Lim Do-Hyun Owner Developer/project Manager, bluebamus@gmail.com  
  Personal github.io : [bluebamus.github.io]

<!-- Markdown link & img dfn's -->

[devspoon-web]: https://github.com/devspoons/devspoon-web
[OpenProject(KR)]: http://wiki.webnori.com/display/pms/Open+Project+7
[Jenkins(KR)]: https://jjeongil.tistory.com/810
[Harbor(KR)]: https://engineering.linecorp.com/ko/blog/harbor-for-private-docker-registry/
[mailgun]: https://www.mailgun.com/
[sendgrid]: https://sendgrid.com/
[OpenProject]: https://docs.openproject.org/user-guide/wiki/
[Jenkins]: https://en.wikipedia.org/wiki/Jenkins_(software)
[Gitolite]: https://wiki.archlinux.org/index.php/Gitolite
[Harbor]: https://en.wikipedia.org/wiki/Harbor
[bluebamus.github.io]: bluebamus.github.io
