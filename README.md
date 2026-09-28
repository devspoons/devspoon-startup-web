# devspoon-startup-web

devspoon-startup-web is an integrated management solution that allows you to easily build the solutions needed for startups (Plane, Jenkins, Gitea [private git server], Harbor [private Docker server]).
Docker Compose files can be used to install various development, backup, and management services singly or collectively.
This repository is based on the [devspoon-web](https://github.com/devspoons/devspoon-web) project. devspoon-web is an open source that allows you to easily build a web or API based on php, python, django, nginx, and redis using Docker Compose.

# introduce "Devspoon-Projects"

- We provide an open source infrastructure integration solution that can easily service Python, Django, PHP, etc. using Docker Compose. You can install the commercial-level customizable nginx service and redis at once, and install and manage more services at once. If you are interested, please visit [Devspoon-Projects](https://github.com/devspoon/Devspoon-Projects).

# Official guide document

- preparing...

## Project management solutions

이 저장소가 함께 설치할 수 있는 솔루션 4종입니다. 각 항목의 상세 설명·구성·설치 방법은 아래 링크를 따라가세요.

| 솔루션 | 무엇을 하는가 | 컨테이너 | 설치 방식 | 상세 |
|---|---|---|---|---|
| **[Plane]** | 프로젝트 관리 — 이슈 · 사이클 · 모듈 | 13개 | compose (단독 / 전체) | [Plane](#plane) |
| **[Jenkins]** | CI — 빌드 · 테스트 · 배포 자동화 | 2개 | compose (단독 / 전체) | [Jenkins](#jenkins) |
| **[Gitea]** | 자체 호스팅 git 서비스 | 1개 | compose (단독 / 전체) | [Gitea](#gitea) |
| **[Harbor]** | Private Docker Registry | installer 가 생성 | **자체 installer** (별도 호스트 권장) | [Harbor](#harbor) |

Plane · Jenkins · Gitea 셋은 한 nginx 뒤에 **함께** 띄울 수도 있고(→ [전체 구축](#설치-방식--전체-구축-vs-단독-구축)), 필요한 것만 **하나씩** 띄울 수도 있습니다(→ [단독 구축](#project_mng_service--단독-구축)).

## Features

- **Web stacks ported from devspoon-web** : `compose/web_service/` has five stacks — `nginx_gunicorn`, `nginx_uvicorn`, `nginx_uwsgi`, `nginx_daphne` (Python / Django 6, uv) and `nginx_php` (PHP 8.4 only). See [Web stack & CI](#web-stack--ci).

- **User custom installation support** : You can selectively install only the desired solution at `compose/project_mng_service/<solution>` without having to install all the solutions. Run only one standalone service at a time (see [단독 서비스 동시 기동 규칙](#단독-서비스-동시-기동-규칙)).

- **All-in-one combinations** : To run a web stack together with Plane, Jenkins and Gitea, use one of the five files in `compose/master_service/` (see [master_service](#master_service--전체-구축-웹-스택--plane--jenkins--gitea)).

- **Access web server and project management solutions with one nginx through nginx proxy** : In master_service, one nginx serves the web app and reverse-proxies Plane, Jenkins and Gitea by domain.

  ```
  Example

  test.com -> company website
  plane.test.com -> Plane solution
  jen.test.com -> jenkins solution
  ```

- **Secret separation (`.env-example`)** : Every compose folder ships a tracked `.env-example`, while the actual `.env` is gitignored. Copy it to `.env`, then generate the empty secrets with `script/lib/django_secrets.sh` (`ensure_env_secrets`); never commit the live file. `${VAR:?}` checks in the compose files fail-fast if a required secret is missing.

- **etc** :

  - You can use ssh (port 2222) for git over SSH on Gitea.
  - Harbor is installed with its own installer scripts (see [Harbor](#harbor)).

## considerations

- **Development-oriented docker service** : This open source is perfect for startups or new service development teams that require frequent modifications and testing.

- **this open-source considers generic servers that are not support AWS, GCM** : This open source is intended to be installed and operated on a server that is directly operated, and on general server hosting, and plans to integrate with cloud services such as AWS and GCM in the future

- **Requirements** : Docker Engine with the Compose plugin (`docker compose`, **≥ 2.17** for the Python app image builds). Legacy `docker-compose` (v1) commands are not used except by the bundled Harbor installer.

## Web stack & CI

웹 스택 서술은 정본 [devspoon-web] README 와 같습니다(검수 완료본을 이 저장소 구조에 맞춤). 모든 명령은 저장소 루트 기준입니다.

### 스택 5종

| 스택 | compose 폴더 | app 서비스 | nginx 설정 폴더 | 프로파일 | 호스트 포트 |
|---|---|---|---|---|---|
| gunicorn | `compose/web_service/nginx_gunicorn` | `gunicorn-app` | `config/web-server/nginx/gunicorn` | `celery` | 80, 443, `127.0.0.1:5555`(flower) |
| uvicorn | `compose/web_service/nginx_uvicorn` | `uvicorn-app` | `config/web-server/nginx/uvicorn` | `celery` | 80, 443, `127.0.0.1:5555` |
| uwsgi | `compose/web_service/nginx_uwsgi` | `uwsgi-app` | `config/web-server/nginx/uwsgi` | `celery` | 80, 443, `127.0.0.1:5555` |
| daphne | `compose/web_service/nginx_daphne` | `daphne-app` | `config/web-server/nginx/gunicorn` (공유) | `celery` | 80, 443, `127.0.0.1:5555` |
| php 8.4 | `compose/web_service/nginx_php` | `php-app` | `config/web-server/nginx/php` | `redis` | 80, 443 |

- Python 스택은 `webserver`·app·`redis` 가 항상 뜨고, `--profile celery` 가 `celery`·`celery-beat`·`flower` 를 더합니다. php 스택은 `webserver`·`php-app` 이 뜨고 `--profile redis` 가 `redis` 를 더합니다.
- 모든 스택이 80/443 을 쓰므로 한 호스트에서 한 스택만 기동합니다.
- 샘플 앱: Python 스택은 `www/django_sample`, php 스택은 `www/php_sample`.

### 1. `.env` 비밀값 생성 (최초 설정 · 업그레이드)

`.env-example` 의 비밀값(Python 스택 `DJANGO_SECRET_KEY` · `REDIS_PASSWORD` · `FLOWER_PWD`, php 스택 `REDIS_PASSWORD`)은 **빈 값**입니다. compose 가 `${VAR:?}` 로 요구하므로 비워 둔 채로는 기동이 거부됩니다. 저장소 루트에서 스택마다 한 번:

```bash
D=compose/web_service/nginx_gunicorn
cp "$D/.env-example" "$D/.env"
bash -c ". script/lib/django_secrets.sh && ensure_env_secrets $D/.env"
```

- 값이 비었거나 옛 `CHANGE_ME_*` 인 비밀 키만 `openssl rand -hex` 무작위 값으로 채웁니다(`DJANGO_SECRET_KEY` 100 hex, `*_KEY_BASE` 128 hex, 그 외 64 hex). 이미 값이 있는 키는 바꾸지 않습니다.
- 같은 폴더의 임시 파일에 쓴 뒤 교체하며, 값을 생성했으면 권한을 600 으로 좁힙니다(더 엄격하면 유지). openssl 이 없거나 실패하면 `FAIL` 로 끝나고 `.env` 내용은 바뀌지 않습니다.
- **비밀이 아닌 자리표시자는 헬퍼가 채우지 않습니다.** 운영 전에 직접 입력하세요.

  | 키 | 어디에 | 값 |
  |---|---|---|
  | `FLOWER_ID` | 웹 스택 · master | flower 로그인 ID (기본값 `CHANGE_ME_FLOWER_USER`) |
  | `DJANGO_ALLOWED_HOSTS` | 웹 스택 · master | 서비스할 도메인 추가 |
  | `PLANE_DOMAIN` · `PLANE_WEB_URL` · `PLANE_CORS_ALLOWED_ORIGINS` | master · 단독 plane | 셋 다 같은 도메인. proxy conf 의 `server_name` 과도 같아야 합니다 |
  | `GITEA_DOMAIN` · `GITEA_ROOT_URL` | master · 단독 gitea | 도메인과 전체 URL |
- 호스트에서 `manage.py` 를 직접 실행할 때만 `www/django_sample` 의 `secrets.json` 이 필요합니다: `bash -c '. script/lib/django_secrets.sh && ensure_django_secrets'` (없을 때만 생성, 600). 컨테이너는 `DJANGO_SECRET_KEY` 환경변수를 씁니다.

> **업그레이드 노트 — 이전 버전에서 쓰던 `.env` 를 유지하는 경우**
>
> 옛 `.env` 에는 `DJANGO_SECRET_KEY` 줄이 아예 없거나 `CHANGE_ME_*` 값이 남아 있을 수 있습니다. 같은 `.env` 에 위 헬퍼를 한 번 실행하면 정리됩니다.
>
> 헬퍼는 이렇게 동작합니다.
>
> - **어디를 보는가**: 같은 폴더의 `docker-compose*.yml`, 그리고 그 파일들이 `include:` 로 참조하는 조각(`compose/common/*.yml`).
> - **무엇을 찾는가**: 그 파일들이 `:?` 로 요구하는 키 중 이름에 SECRET · PASSWORD · PWD 가 들어가거나 `_KEY_BASE` 로 끝나는 것.
> - **무엇을 하는가**: 없는 키는 파일 끝에 추가하고, `CHANGE_ME_*` 는 새 값으로 바꿉니다. 이미 값이 있는 키는 건드리지 않고, 파일 권한을 600 으로 맞춥니다.
>
> `KEY=""` 처럼 따옴표로 감싼 빈 값은 채우지 않습니다. 먼저 `KEY=` 로 고쳐 두세요.
>
> 이전 버전은 `compose/web_service/*`·`compose/master_service`·`compose/project_mng_service/*` 의 `.env` 를 git 으로 추적했습니다. 이 버전에서 추적이 해제되어 `git pull` 이 로컬 `.env` 를 지울 수 있으니 **pull 전에 `.env` 를 다른 곳에 복사**해 두세요. 이전에 저장소에 공개됐던 `secrets.json`·`.env` 의 키로 운영 중이라면 새 값으로 교체하세요(세션 무효화).

### 2. 기동

§1 의 `.env` 명령(저장소 루트) 뒤, 저장소 루트에서 스택 폴더로 이동해 기동합니다(`--build` 는 업그레이드나 Dockerfile / `uv.lock` 변경 뒤 이미지를 다시 빌드합니다). 한 호스트에 한 스택만 띄웁니다.

```bash
# gunicorn (저장소 루트에서)
cd compose/web_service/nginx_gunicorn
docker compose up -d --build             # webserver + gunicorn-app + redis
docker compose --profile celery up -d    # + celery · celery-beat · flower
```

uvicorn · uwsgi · daphne 는 gunicorn 과 같은 명령이며 폴더 이름만 `compose/web_service/nginx_uvicorn` · `nginx_uwsgi` · `nginx_daphne` 로 바꿉니다.

```bash
# php (저장소 루트에서)
cd compose/web_service/nginx_php
docker compose up -d --build             # webserver + php-app
docker compose --profile redis up -d     # + redis
```

- **기동 순서 — app 이 DB 를 초기화한 뒤 celery · beat 가 뜹니다.**
  DB 초기화는 app 서비스 **하나만** 수행합니다. `manage.py` 가 있으면 `python manage.py migrate --noinput`, 없으면 프로젝트의 `prestart.sh` 를 돌립니다.
  `celery` · `celery-beat` 는 `depends_on: <app>: condition: service_healthy` 로 묶여 app 이 healthy 가 된 뒤에 뜹니다. 여러 컨테이너가 동시에 migrate 하는 경쟁이 없습니다.
- **Flower** 는 **`127.0.0.1:5555` 에만 바인드**됩니다. 원격 접근은 SSH 터널: `ssh -L 5555:127.0.0.1:5555 <host>` 후 로컬 브라우저에서 `http://127.0.0.1:5555`.
- `DJANGO_DEBUG`(기본 `0`) · `DJANGO_ALLOWED_HOSTS` 를 `.env` 로 제어하며 app · celery · beat 에 전달됩니다. `DJANGO_DEBUG=1` 은 로컬 개발에서만 쓰세요.
> ⚠️ **`docker compose down -v` 는 named volume 을 삭제합니다.** 웹 스택의 앱 데이터, master_service 의 Plane 데이터(`plane-pgdata` 등), Gitea 저장소(`gitea-data`)가 모두 여기에 해당합니다. 컨테이너만 내릴 때는 `stop` 을 쓰세요.

- 컨테이너는 `docker compose stop` / `start` / `restart` 로 운영합니다. 프로필 서비스까지 대상이면 기동과 같은 프로필을 붙입니다(`docker compose --profile celery stop`, php 는 `--profile redis stop`) — 프로필 없는 `stop` 은 celery · celery-beat · flower(php 는 redis) 컨테이너를 남깁니다.

### 3. 이미지 이름 · 빌드 · uv

- **이미지 이름**은 `${IMAGE_NAMESPACE:-devspoon}-nginx:latest` 형식입니다(`-py-app:latest` · `-uwsgi-app:latest` · `-php-app:8.4`). 기본값이면 `devspoon-*` 태그가 됩니다.

  테스트는 운영 태그를 덮어쓰지 않도록 다른 네임스페이스를 씁니다 — 검증기와 `verify-ngxblocker.sh` 는 `IMAGE_NAMESPACE=devspoon-it`, run-ci 의 빌드 단계(`s2_build.sh`)는 `devspoon-test/*`.
- 앱 이미지(`py-app` · `uwsgi-app`)의 사전 설치 패키지는 `www/django_sample/uv.lock` 에서 도출됩니다. compose 는 `build.additional_contexts: lock: ../../../www/django_sample` 로 이를 자동 전달하므로 **Docker Compose ≥ 2.17** 이 필요합니다 (`docker compose version`).
- Compose 가 2.17 미만이거나 `docker build` 를 직접 쓸 때는 추가 빌드 컨텍스트를 명시합니다(저장소 루트, BuildKit):

  ```bash
  docker build --build-context lock=www/django_sample -t devspoon-py-app:latest docker/gunicorn/
  docker build --build-context lock=www/django_sample -t devspoon-uwsgi-app:latest docker/uwsgi/
  ```

  빠뜨리면 빌드가 `"/pyproject.toml": not found` 로 실패합니다.
- **uv** — `www/django_sample` 의 의존성은 `pyproject.toml` · `uv.lock` 으로 관리합니다. 컨테이너는 가상환경 없이 시스템 Python 에 설치하고(`UV_PROJECT_ENVIRONMENT=/usr/local`), 기동 명령이 `uv sync --inexact --extra <stack> --extra celery` 를 실행합니다. 같은 스택의 app · celery · celery-beat 는 같은 extras 로 sync 합니다.

  의존성을 추가할 때는 순서가 있습니다.

  ```bash
  cd www/django_sample && uv add <pkg>        # 1. 호스트에서 추가 → uv.lock 커밋
  cd compose/web_service/nginx_gunicorn        # 2. 스택 폴더로
  docker compose --profile celery stop
  docker compose up -d --build                 # 3. 앱 이미지 재빌드
  docker compose --profile celery up -d        # 4. celery · celery-beat 도 다시 올림
  ```

  4번을 빠뜨리면 celery 쪽이 옛 의존성으로 계속 돕니다. celery 서비스에는 `build:` 가 없어 app 과 같은 이미지를 참조만 하기 때문에, 프로필 없는 `up --build` 만으로는 교체되지 않습니다.

### 4. nginx · php 설정

- **nginx conf 생성기** — `config/web-server/nginx/<gunicorn|uvicorn|uwsgi|php>/` 에 있는 `nginx_http_conf.sh` · `nginx_https_conf.sh` 가 `sample_nginx_http(s).conf` 를 바탕으로 도메인별 conf 를 `conf.d/` 에 만듭니다. 옵션은 `-h` 로 확인하세요. daphne 스택은 gunicorn 폴더를 그대로 씁니다.
- **nginx 기동 훅** — 이미지의 `/docker-entrypoint.d/30-wait-upstreams.sh` 가 conf 에 적힌 upstream(앱 컨테이너) 이름이 해석될 때까지 기다렸다가 nginx 를 띄웁니다. 대기 시간은 `NGINX_UPSTREAM_WAIT` 초(기본 30, `0` 이면 비활성)이며 webserver 의 `environment` 로 조정합니다.

  재부팅이나 `start` 처럼 app 보다 webserver 가 먼저 뜨는 상황에서 `[emerg] host not found in upstream` 으로 죽는 것을 막아 줍니다. 다만 전체 `docker compose restart` 는 모두가 동시에 재시작하므로 훅으로도 완전히 막히지 않습니다 — **conf 반영은 `nginx -s reload`, 전체 재기동은 `stop` → `start`** 를 쓰세요.
- **php-fpm pool 은 `config/app-server/php/pool.d/www.conf` 를 직접 편집**합니다. compose 가 읽기 전용으로 마운트하는 파일은 그 `www.conf` 와 `config/app-server/php/php_ini/php.ini` 둘뿐입니다. 그래서 `php_conf.sh` 가 `pool.d/` 에 만드는 `<DOMAIN>_php.conf` 는 로드되지 않습니다.

### 5. CI — `script/ci/run-ci.sh`

#### 무엇을 위한 스크립트인가

저장소를 고친 뒤 **"이 저장소의 모든 스택이 여전히 실제로 뜨는가"** 를 한 번에 확인하는 회귀 테스트 묶음입니다. 문법 검사에서 끝나지 않고 컨테이너를 실제로 띄워 응답까지 받아 봅니다.

GitHub Actions(`.github/workflows/test.yml`)가 push 마다 같은 스크립트를 호출하고, 개발자가 로컬에서 `bash script/ci/run-ci.sh` 로 똑같이 돌릴 수도 있습니다.

#### 어떻게 동작하는가

11개 단계를 **순서대로** 실행하고, 한 단계라도 실패하면 **즉시 중단**합니다. 단계마다 로그를 `log/ci/` 에 남기고, 실패 시 "어느 단계에서 무슨 오류로" 실패했는지 로그 끝부분과 함께 알립니다.

| # | 단계 | 하는 일 |
|---|---|---|
| 1 | preflight | 필요한 도구·파일이 있는지, 설계 불변식이 지켜졌는지 확인 (읽기 전용) |
| 2 | prereq·로그 디렉터리 | 테스트가 쓸 로그 폴더 생성 |
| 3 | nginx conf 생성기 | `nginx_http_conf.sh` · `nginx_https_conf.sh` 가 만든 conf 가 설정대로 나오는지 |
| 4 | compose 검증 | 모든 스택의 compose 문법과 마운트 경로 |
| 5 | 저장소 고유 검사 | `script/ci/repo-steps.sh` — 이 저장소에만 있는 규칙(Plane·Gitea·Jenkins·Harbor 관련 정적 단언) |
| 6 | 이미지 빌드 | 모든 Dockerfile 을 `devspoon-test/*` 태그로 빌드 (운영 태그를 덮어쓰지 않음) |
| 7 | 정적 회귀 | `s6_regression.sh` — 과거에 고친 결함이 되살아나지 않았는지 검사하는 불변식 모음 |
| 8 | healthcheck | 5개 스택의 healthcheck·`depends_on` 선언 검증 |
| 9 | 스택 매트릭스 | gunicorn · uvicorn · uwsgi · daphne · php 를 **차례로 실제 기동** — 200 응답, 봇 차단, healthy, 재시작 0회, DEBUG off, 업로드 경로 403 |
| 10 | 샘플 프로젝트 | django · php 샘플이 동작하는지 |
| 11 | 스크립트 로그 | 스크립트들이 로그를 제대로 남기는지 |

#### 실행 조건

- 실제 컨테이너를 띄우므로 **호스트 80 · 443 · 5555 포트가 비어 있어야** 합니다.
- 필요한 도구: docker(Compose ≥ 2.17), uv, jq, curl, openssl, php-cli.
- 알림은 선택입니다. 저장소 secrets 에 `SLACK_WEBHOOK_URL` · `TELEGRAM_BOT_TOKEN` · `TELEGRAM_CHAT_ID` 가 없으면 해당 알림만 건너뛰고 테스트는 그대로 진행합니다.
- 업로드하는 로그(`log/ci`, `log/test_run`)는 `script/lib/mask_secrets.sh` 로 비밀값을 가린 뒤 올립니다.

#### 쓰지 않으려면

CI 는 저장소 운영에만 쓰이고 서비스 기동과는 무관합니다. 필요 없으면 `.github/workflows/test.yml` 만 지우면 Actions 가 돌지 않고, `script/ci/` · `script/test_run/` 을 통째로 지워도 `compose/` 아래 서비스 기동에는 영향이 없습니다.

## 설치 방식 — 전체 구축 vs 단독 구축

Plane · Jenkins · Gitea 는 **두 가지 방식**으로 설치합니다. 어느 쪽이든 서비스 정의는 `compose/common/` 의 같은 파일을 쓰므로 동작은 동일하고, 앞단 nginx 를 공유하느냐만 다릅니다.

| | 전체 구축 (`compose/master_service`) | 단독 구축 (`compose/project_mng_service`) |
|---|---|---|
| 무엇이 뜨는가 | 웹 스택 + Plane + Jenkins + Gitea 를 **한 번에** | 고른 서비스 **하나만** |
| nginx | 웹 앱과 세 솔루션을 **한 nginx** 가 도메인별로 프록시 | 서비스 전용 nginx 하나 |
| 동시 기동 | 전부 함께 뜸 | **한 번에 하나만** (80/443 을 서로 뺏음) |
| TLS | 구성 가능 ([HTTPS 절](#setting-up-https-on-a-web-server)) | **HTTP 전용** |
| 쓰는 경우 | 운영, 여러 솔루션을 같이 쓸 때 | 하나만 평가·시험할 때 |

Harbor 는 자체 installer 로 설치하며 두 방식 어디에도 포함되지 않습니다 — [Harbor](#harbor) 참고.

```
전체 구축 예시 — nginx 하나가 도메인으로 갈라 보냄

  test.com        →  웹 앱 (django / php)
  plane.test.com  →  Plane
  jen.test.com    →  Jenkins
  git.test.com    →  Gitea   (+ ssh://…:2222 로 git clone)
```

## master_service — 전체 구축 (웹 스택 + Plane · Jenkins · Gitea)

`compose/master_service/` 의 5조합은 한 nginx(`webserver`) 뒤에 웹 스택과 Plane · Jenkins · Gitea 를 함께 띄웁니다. `.env` 하나(`compose/master_service/.env-example`)를 공유하고, Plane · Gitea 서비스 정의는 단독 스택과 같은 `compose/common/{plane-services,gitea-service}.yml` 을 `include:` 합니다(**Docker Compose ≥ 2.20**).

| 파일 | 웹 스택 | 프로파일 |
|---|---|---|
| `docker-compose-gunicorn.yml` | gunicorn | `celery` |
| `docker-compose-uvicorn.yml` | uvicorn | `celery` |
| `docker-compose-uwsgi.yml` | uwsgi | `celery` |
| `docker-compose-daphne.yml` | daphne | `celery` |
| `docker-compose-php.yml` | php 8.4 | `redis` (celery 없음) |

모든 조합에 **Plane**(`makeplane/plane-*`, 앱·DB·큐·오브젝트 저장소·내부 프록시 13 서비스) · `jenkins`(`jenkins/jenkins:lts-jdk21`) · **Gitea**(`gitea/gitea`, 호스트 2222 = git over SSH) 가 포함됩니다.

1. **Plane · Gitea 는 사전 준비가 없습니다** — 관리자 계정은 기동 뒤에 만듭니다([Plane](#plane) 6 · [Gitea](#gitea) 4단계).
2. **`.env` 생성** — Plane 비밀 키 5종도 헬퍼가 생성합니다(`include:` 한 `compose/common/plane-services.yml` 의 `${KEY:?}` 까지 훑습니다).

   ```bash
   D=compose/master_service
   cp "$D/.env-example" "$D/.env"
   bash -c ". script/lib/django_secrets.sh && ensure_env_secrets $D/.env"
   ```

   이어서 `PLANE_DOMAIN` · `PLANE_WEB_URL` · `PLANE_CORS_ALLOWED_ORIGINS` · `GITEA_DOMAIN` · `GITEA_ROOT_URL` · `FLOWER_ID` 자리표시자를 직접 입력합니다.
3. **proxy 샘플 복사** — webserver 가 `config/web-server/nginx/php/proxy/<svc>/` 를 `/etc/nginx/proxy.d/<svc>/` 로 읽기 전용 마운트하고, `nginx.conf` 가 `include /etc/nginx/proxy.d/*/*.conf;` 로 읽습니다. `conf.d` 로 복사하지 않습니다.

   ```bash
   P=config/web-server/nginx/php/proxy
   cp "$P/plane/plane_proxy.conf.example" "$P/plane/plane_proxy.conf"                           # server_name 수정
   cp "$P/gitea/gitea_proxy.conf.example" "$P/gitea/gitea_proxy.conf"                           # server_name 수정
   cp "$P/jenkins/jenkins_proxy.conf.example" "$P/jenkins/jenkins_proxy.conf"                   # server_name 수정
   ```

   복사본(`*_proxy.conf`, gitignore)이 없으면 주석뿐인 `default.conf` 만 읽혀 해당 proxy 가 비활성입니다. 샘플은 HTTP(80) 서버 블록만 있으므로 TLS 는 [HTTPS 절](#setting-up-https-on-a-web-server)로 443 블록을 추가합니다.
4. **기동** — 저장소 루트에서 스택 폴더로 이동합니다(`--build` 는 업그레이드나 Dockerfile / `uv.lock` 변경 뒤 이미지를 다시 빌드합니다).

   ```bash
   cd compose/master_service
   docker compose -f docker-compose-gunicorn.yml --profile celery up -d --build
   docker compose -f docker-compose-php.yml --profile redis up -d --build      # php 조합
   ```

   > ⚠️ **첫 기동은 Plane 마이그레이션 때문에 수 분 걸립니다**: `plane-migrator` 가 성공으로 끝난 뒤 `plane-api` 가 뜨고, 그 뒤에 `plane-proxy` 가 준비됩니다. Plane · Gitea 데이터는 named volume 이므로 호스트 폴더를 만들 필요가 없습니다(`docker compose down -v` 는 그 볼륨을 지웁니다).

## project_mng_service — 단독 구축

### 단독 서비스 동시 기동 규칙

- **단독 서비스는 한 번에 하나만 기동합니다.** `nginx_plane` · `nginx_jenkins` · `gitea` 가 모두 호스트 80/443(또는 2222)을 쓰고, `plane-*` · `jenkins` · `gitea` 컨테이너 이름이 master_service 와 같습니다. 웹 스택(`compose/web_service`)·master_service 와도 동시에 띄울 수 없습니다.
- **여러 서비스를 동시에 운영하려면 master_service 를 쓰세요.**
- **단독 스택은 HTTP 전용입니다(80 만, TLS 없음).**
  443 포트가 매핑돼 있긴 하지만 서비스용 TLS 서버 블록이 없습니다. catch-all `default.conf` 가 TLS 핸드셰이크를 거부할 뿐입니다(`ssl_reject_handshake on`). 즉 **로그인 자격증명이 평문으로 오갑니다.**
  공개망에서 쓰려면 앞단에 TLS 종단(별도 리버스 프록시 · LB)을 두거나, TLS 를 구성할 수 있는 master_service 를 쓰세요.

**단독 스택의 nginx 는 이렇게 구성됩니다.**

- 서비스별 폴더 `config/web-server/nginx/php/proxy/<svc>/` 를 `/etc/nginx/conf.d/` 로 읽기 전용 마운트합니다.
- 그 폴더의 자리표시자 `default.conf` 위에 catch-all `config/web-server/nginx/php/conf.d/default.conf` 를 덮어 마운트합니다.
- 복사본 `<svc>_proxy.conf` 를 만들지 않으면 모든 Host 에 444 를 돌려주며 **정상 기동**합니다.

> 자리표시자 `default.conf` 는 읽기 전용 마운트 지점입니다. 편집하거나 지우지 마세요.

### Plane

#### 서비스 설명

이슈 트래킹과 스프린트 관리를 하는 오픈소스 프로젝트 관리 도구입니다(Jira 계열). 워크스페이스 아래 프로젝트를 만들고, 이슈를 **사이클**(반복 주기)과 **모듈**(기능 묶음)로 나눠 관리합니다. 보드·리스트·캘린더·간트 뷰를 제공하고 여러 사람이 같은 문서를 동시에 편집할 수 있습니다.

인스턴스 전체 설정(가입 허용 여부, 인증 방식, 메일)은 **God Mode** 라는 별도 관리 화면에서 합니다.

#### 구성

컨테이너 13개가 한 묶음으로 동작합니다. 정의는 `compose/common/plane-services.yml` **한 곳**에 있고, 단독 스택과 master_service 5조합이 이 파일을 `include:` 로 함께 씁니다(**Docker Compose ≥ 2.20** 필요).

| 역할 | 컨테이너 | 이미지 |
|---|---|---|
| 웹 UI | `plane-web` | `makeplane/plane-frontend` |
| 공개 페이지 | `plane-space` | `makeplane/plane-space` |
| 관리 화면(God Mode) | `plane-admin` | `makeplane/plane-admin` |
| API 서버 | `plane-api` | `makeplane/plane-backend` |
| 실시간 협업(WebSocket) | `plane-live` | `makeplane/plane-live` |
| 백그라운드 작업 | `plane-worker` · `plane-beat-worker` | `makeplane/plane-backend` |
| DB 마이그레이션(1회성) | `plane-migrator` | `makeplane/plane-backend` |
| 데이터베이스 | `plane-db` | `postgres:15.7-alpine` |
| 캐시 | `plane-redis` | `valkey/valkey:7.2.11-alpine` |
| 메시지 큐 | `plane-mq` | `rabbitmq:3.13.6-management-alpine` |
| 첨부 파일 저장소 | `plane-minio` | `quay.io/minio/minio` (S3 호환) |
| 스택 내부 프록시 | `plane-proxy` | `makeplane/plane-proxy` (Caddy) |

- **호스트 포트를 열지 않습니다.** 앞단 nginx 가 `plane-proxy` 로 프록시합니다.
- **데이터는 전부 named volume** 입니다: `plane-pgdata`(DB) · `plane-uploads`(첨부) · `plane-rabbitmq` · `plane-redisdata` · `plane-proxy-*` · `plane-logs-*`. 호스트 폴더를 미리 만들 필요가 없습니다.
- 업스트림 `deployments/cli/community/docker-compose.yml` 을 기준으로, 호스트 포트를 닫고 앞단 nginx 뒤에 두도록 조정했습니다.

#### 단독 설치 및 사용

1. **`.env` 생성** — 비밀 키 5종(`PLANE_SECRET_KEY` · `PLANE_LIVE_SERVER_SECRET_KEY` · `PLANE_DB_PASSWORD` · `PLANE_MQ_PASSWORD` · `PLANE_MINIO_PASSWORD`)이 비어 있으면 compose 가 기동을 거부합니다. 헬퍼가 `include:` 한 정의까지 훑어 채웁니다.

   ```bash
   D=compose/project_mng_service/nginx_plane
   cp "$D/.env-example" "$D/.env"
   bash -c ". script/lib/django_secrets.sh && ensure_env_secrets $D/.env"
   ```

2. **도메인 입력** — `PLANE_DOMAIN` · `PLANE_WEB_URL` · `PLANE_CORS_ALLOWED_ORIGINS` 세 값을 **같은 도메인**으로 직접 적습니다(헬퍼가 채우지 않습니다). proxy conf 의 `server_name` 과도 같아야 로그인·API·실시간 협업이 모두 동작합니다. HTTPS 로 서비스하면 URL 두 개를 `https://` 로 적습니다.

3. **proxy conf 준비** (저장소 루트에서)

   ```bash
   P=config/web-server/nginx/php/proxy/plane
   cp "$P/plane_proxy.conf.example" "$P/plane_proxy.conf"   # server_name 을 실제 도메인으로 수정
   ```

4. **기동**

   ```bash
   cd compose/project_mng_service/nginx_plane
   docker compose up -d
   ```

   첫 기동은 **수 분** 걸립니다. `plane-migrator` 가 DB 마이그레이션을 끝내야 `plane-api` 가 뜨고, 그 뒤에 나머지가 준비됩니다.

5. **첫 계정** — 브라우저로 도메인에 접속해 가입하면 그 계정이 인스턴스의 첫 사용자가 됩니다. 인스턴스 관리는 같은 도메인의 `/god-mode/` 로 들어갑니다. 외부 가입을 막으려면 God Mode 의 Authentication 설정에서 sign-up 을 끕니다.

6. **백업**

   ```bash
   D=compose/project_mng_service/nginx_plane   # master: D=compose/master_service + -f docker-compose-<stack>.yml
   (cd "$D" && docker compose exec -T plane-db pg_dump -U plane -d plane) | gzip > ~/plane-db-$(date +%F).sql.gz
   chmod 600 ~/plane-db-*.sql.gz               # 사용자·워크스페이스 데이터가 들어 있습니다
   ```

   첨부 파일은 `plane-uploads` 볼륨에 있습니다: `docker run --rm -v plane-uploads:/d -v "$HOME":/b alpine tar czf /b/plane-uploads.tgz -C /d .`

> ⚠️ **비밀값을 바꾸면 기존 DB 와 어긋납니다.** `PLANE_DB_PASSWORD` 는 `plane-pgdata` 볼륨을 처음 만들 때의 PostgreSQL 비밀번호로 굳습니다. `.env` 를 새로 만들어 값이 달라지면 `plane-migrator` 가 `FATAL: password authentication failed for user "plane"` 으로 실패하고, 뒤따르는 컨테이너가 전부 못 뜹니다.
> 값을 바꾸려면 DB 쪽도 함께 바꾸거나(`docker compose exec plane-db psql -U plane -c "ALTER USER plane PASSWORD '<새 값>';"`), 데이터를 버려도 되면 볼륨을 새로 만드세요(`docker compose down -v`).

자세한 내용은 [Plane 공식 문서][Plane docs]를 참고하세요.

---

### Jenkins

#### 서비스 설명

빌드·테스트·배포를 자동화하는 CI 서버입니다. 코드가 올라올 때마다 정해 둔 작업(Job/Pipeline)을 자동 실행해, 여러 사람이 동시에 개발할 때 생기는 문제를 빨리 찾아냅니다. 플러그인으로 기능을 확장합니다.

#### 구성

| 역할 | 컨테이너 | 이미지 |
|---|---|---|
| Jenkins 본체 | `jenkins` | `jenkins/jenkins:lts-jdk21` |
| 소유권 보정(1회성) | `jenkins-init` | 같은 이미지를 root 로 실행 |

- 데이터는 compose 폴더 아래 **호스트 디렉터리 `jenkins_home`** 에 쌓입니다(Plane·Gitea 와 달리 named volume 이 아닙니다).
- jenkins 이미지는 컨테이너 안에서 **uid 1000** 으로 동작합니다. 그래서 기동할 때마다 `jenkins-init` 이 먼저 `jenkins_home` 의 소유자를 1000 으로 맞춥니다. 저장소를 클론한 호스트 계정의 uid 가 1000 이 아니어도 `missing rw permissions on JENKINS_HOME` 재시작 루프가 생기지 않습니다. 이 때문에 호스트에서는 `jenkins_home` 이 uid 1000 소유로 보입니다(master_service 도 동일).
- 호스트 포트를 열지 않고 컨테이너 8080 을 앞단 nginx 가 프록시합니다.

#### 단독 설치 및 사용

1. **proxy conf 준비** (저장소 루트에서)

   ```bash
   P=config/web-server/nginx/php/proxy/jenkins
   cp "$P/jenkins_proxy.conf.example" "$P/jenkins_proxy.conf"   # server_name 수정
   ```

2. **`.env` 생성** — 로그 설정만 있고 비밀값은 없습니다.

   ```bash
   D=compose/project_mng_service/nginx_jenkins
   cp "$D/.env-example" "$D/.env"
   ```

3. **기동** — `--build` 는 업그레이드나 Dockerfile 변경 뒤 nginx 이미지를 다시 만들 때 붙입니다.

   ```bash
   cd compose/project_mng_service/nginx_jenkins
   docker compose up -d --build
   ```

4. **첫 로그인** — 초기 관리자 비밀번호를 꺼내 웹 UI 에 입력합니다.

   ```bash
   docker compose exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
   ```

자세한 내용은 [Jenkins 공식 문서](https://www.jenkins.io/doc/)를 참고하세요.

---

### Gitea

#### 서비스 설명

직접 호스팅하는 가벼운 Git 서비스입니다. 저장소 관리, 웹 UI, 이슈, 풀 리퀘스트, 조직·권한 관리를 제공하고 SSH 와 HTTP 양쪽으로 clone·push 를 받습니다. GitHub 을 쓰지 않고 사내에 코드를 두고 싶을 때 씁니다.

#### 구성

| 역할 | 컨테이너 | 이미지 |
|---|---|---|
| Gitea 본체 | `gitea` | `gitea/gitea` |

- 컨테이너 **하나**로 끝납니다. DB 는 내장 SQLite 를 씁니다. 외부 DB(PostgreSQL 등)로 바꾸려면 `.env` 에 `GITEA__database__*` 를 추가합니다.
- 데이터는 named volume **`gitea-data`** 한 곳에 모입니다(저장소 · DB · SSH 호스트키).
- **HTTP** 는 호스트 포트를 열지 않고 컨테이너 3000 을 앞단 nginx 가 프록시합니다.
- **git over SSH** 는 컨테이너가 호스트 `2222`(`GITEA_SSH_PORT`)를 직접 게시합니다. 컨테이너 안에서는 이미지에 포함된 OpenSSH 가 22 번을 서비스합니다.
- 설치 마법사는 `INSTALL_LOCK` 으로 건너뜁니다 — `.env` 값으로 설정이 확정됩니다.

#### 단독 설치 및 사용

1. **`.env` 생성 후 도메인 입력** — 비밀값은 없습니다.

   ```bash
   D=compose/project_mng_service/gitea
   cp "$D/.env-example" "$D/.env"      # GITEA_DOMAIN · GITEA_ROOT_URL 수정
   ```

   `GITEA_ROOT_URL` 은 끝에 `/` 를 포함한 전체 URL 입니다(예: `http://git.example.com/`). 웹훅·클론 URL·OAuth 리다이렉트가 이 값을 그대로 씁니다. HTTPS 로 서비스하면 `https://` 로 적습니다.

2. **proxy conf 준비** (저장소 루트에서)

   ```bash
   P=config/web-server/nginx/php/proxy/gitea
   cp "$P/gitea_proxy.conf.example" "$P/gitea_proxy.conf"   # server_name 수정
   ```

3. **기동**

   ```bash
   cd compose/project_mng_service/gitea
   docker compose up -d
   ```

4. **관리자 계정 생성** (최초 1회)

   ```bash
   docker compose exec -u git gitea gitea admin user create \
     --username <id> --password '<pw>' --email <mail> --admin
   ```

   `master_service` 에서는 `cd compose/master_service` 로 옮긴 뒤 위 명령에 `-f docker-compose-<stack>.yml` 을 붙입니다.

   기본값이 `GITEA_DISABLE_REGISTRATION=true` 라 관리자만 계정을 만들 수 있습니다. 자체 가입을 허용하려면 `.env` 에서 `false` 로 바꾸세요.

5. **사용** — 웹 UI 에서 저장소를 만들고 SSH 공개키를 등록한 뒤

   ```bash
   git clone ssh://git@<도메인>:2222/<계정>/<저장소>.git    # SSH
   git clone http://<도메인>/<계정>/<저장소>.git             # HTTP (개인 저장소는 토큰·비밀번호 인증)
   ```

6. **백업**

   ```bash
   docker compose exec -u git gitea gitea dump -c /data/gitea/conf/app.ini -f /tmp/gitea-dump.zip
   docker compose cp gitea:/tmp/gitea-dump.zip ~/
   ```

> ⚠️ **SSH 2222 를 외부에 열려면 방화벽만으로는 부족합니다.** Docker 가 게시한 포트는 호스트 iptables 의 INPUT 체인을 거치지 않습니다. 클라우드라면 보안 그룹(OCI VCN 보안 목록 · AWS 보안 그룹 등)에도 인바운드 2222 를 추가해야 합니다. 빠뜨리면 사설 IP 로는 접속되는데 공인 도메인으로는 timeout 이 납니다.

자세한 내용은 [Gitea 공식 문서][Gitea docs]를 참고하세요.

---

### Harbor

#### 서비스 설명

사내에 두는 Private Docker Registry 입니다. 이미지를 외부 레지스트리에 올리지 않고 직접 보관·배포하며, 프로젝트 단위 접근 권한, 이미지 취약점 스캔, 서명, 복제(replication)를 제공합니다.

#### 구성

**이 저장소의 다른 서비스와 방식이 다릅니다.** compose 정의를 제공하지 않습니다.

대신 Harbor 가 공식 배포하는 **installer 를 번들**해 두었습니다(`compose/project_mng_service/harbor-v2.0.0/`). installer 가 자체 compose 파일을 만들어 여러 컨테이너(포털 · core · registry · DB · job service 등)를 띄웁니다.

- installer 는 `docker compose` 플러그인이 아니라 **`docker-compose` 라는 이름의 명령**을 직접 호출합니다(Compose v1 시절 스크립트).
- Harbor 는 자체 nginx 로 http 포트(기본 80)를 씁니다.

#### 설치 및 사용

1. **레거시 `docker-compose` 명령 준비**

   `common.sh` 의 `check_dockercompose` 가 `docker-compose --version` 출력을 **1.18.0 이상**으로 파싱하지 못하면 `[Step 1]` 에서 중단합니다:

   ```
   Need to install docker-compose(1.18.0+) by yourself first and run this script again.
   ```

   Compose v1 바이너리를 PATH 에 두거나, `docker compose` 플러그인을 부르는 래퍼를 만들면 됩니다. 버전 판정은 **이름이 `docker-compose` 인 명령의 출력만** 보므로 래퍼로도 통과합니다.

   ```bash
   printf '#!/bin/sh\ncase "$1" in --version|version) exec docker compose version ;; esac\nexec docker compose "$@"\n' \
     | sudo tee /usr/local/bin/docker-compose
   sudo chmod +x /usr/local/bin/docker-compose
   ```

   래퍼가 `--version` 을 `version` 으로 바꿔 전달하는 이유는, 최근 Compose 플러그인이 `docker compose --version` 에 버전 대신 사용법을 출력하기 때문입니다. 이 래퍼로 http·https 설치와 기동(포털 · API · 레지스트리 토큰)을 검증했습니다.

2. **설치** — **root 로 실행합니다**(Harbor 공식 안내와 동일).

   ```bash
   cd compose/project_mng_service/harbor-v2.0.0
   sudo bash autoinstall.sh        # 설정 생성 + 설치를 한 번에
   ```

   나눠서 하려면 `bash update_harbor_config.sh` 로 `harbor.yml` 을 만든 뒤 `sudo bash install.sh` 를 실행합니다. 일반 사용자로 돌리면 `prepare` 가 만든 root 소유 600 파일 때문에 `[Step 4]` 에서 `permission denied` 로 멈춥니다. 설치 후 `docker-compose down`·`ps` 같은 명령도 같은 폴더에서 `sudo` 로 실행합니다.

3. **입력값** — 도메인, http 포트, https 사용 여부를 물어봅니다. 경로(ssl · data volume · log)는 `/data` 처럼 **일반 경로 그대로** 적습니다(이스케이프 불필요).

4. **https 를 쓰려면** 설치 전에 인증서를 아래 구조로 둡니다.

   ```
   compose/project_mng_service/harbor-v2.0.0/ssl/letsencrypt/live/<도메인>/{fullchain,privkey}.pem
   ```

   `autoinstall.sh` 가 `ssl/` 내용을 입력한 ssl path 아래로 복사하고(`<ssl path>/letsencrypt/live/<도메인>/…`), `harbor.yml` 의 인증서 경로에 그 도메인을 넣습니다. 기본 경로 `/etc` 는 root 권한이 필요합니다.

5. **실행 권한** — `prepare` 만 저장소에 실행 권한(`100755`)으로 추적됩니다. 나머지(`install.sh` · `autoinstall.sh` · `update_harbor_config.sh` · `common.sh`)는 `100644` 라 위 예시처럼 `bash <스크립트>` 로 실행합니다. `./install.sh` 형태로 쓰려면 그 파일에만 `chmod +x` 하세요.

> ⚠️ **다른 서비스와 같은 호스트에 두지 마세요.** Harbor 는 자체 nginx 로 80 포트를 잡습니다. 이 저장소의 웹 스택 · master_service · 단독 proxy 와 충돌합니다. 같은 호스트에 둬야 한다면 `update_harbor_config.sh` 에서 다른 http 포트를 지정하고, 앞단 nginx(예: master_service proxy conf)에서 그 포트로 프록시하세요.

자세한 내용은 [Harbor 2.0 공식 문서](https://goharbor.io/docs/2.0.0/)를 참고하세요.

## Setting up HTTPS on a web server

HTTP 로 먼저 띄운 뒤 인증서를 발급받고 HTTPS conf 로 교체하는 순서입니다.

> master_service 폴더에는 `docker-compose.yml` 이 없습니다. 아래 모든 `docker compose` 명령에 `-f docker-compose-<stack>.yml` 을 붙이세요.
> 예: `docker compose -f docker-compose-gunicorn.yml exec webserver bash /script/letsencrypt.sh`

1. **HTTP conf 생성** — `config/web-server/nginx/<service>/nginx_http_conf.sh` 를 실행합니다. 도메인마다 conf 가 `conf.d/` 아래 만들어지고, 파일명은 항상 `_http` 로 끝납니다.

2. **HTTP 로 기동** — compose 폴더에서 `docker compose up -d --build`. (`--build` 는 업그레이드나 Dockerfile · `uv.lock` 변경 뒤에만 필요합니다.)

3. **인증서 발급** — `docker compose exec webserver bash /script/letsencrypt.sh` 를 실행하고 도메인과 이메일을 입력합니다. ACME webroot 는 `/www/certbot` 으로 고정이라(생성되는 conf 와 proxy 샘플이 모두 여기서 `/.well-known/acme-challenge/` 를 서비스합니다) 따로 입력하지 않습니다.

4. **HTTPS conf 로 교체** — 같은 폴더의 `nginx_https_conf.sh` 를 실행한 뒤, `conf.d/` 에서 3번까지 쓰던 `_http` conf 를 지웁니다.

5. **proxy conf 는 수동입니다** — Plane · Jenkins · Gitea 의 proxy conf 에는 생성기가 없습니다. 인증서를 받은 뒤 `config/web-server/nginx/php/proxy/<svc>/<svc>_proxy.conf` 에 `listen 443 ssl` 서버 블록을 직접 추가하세요(ssl 지시어는 `config/web-server/nginx/php/sample_nginx_https.conf` 참고).

   URL 을 담는 `.env` 값도 함께 `https://` 로 바꿉니다 — Plane 은 `PLANE_WEB_URL` · `PLANE_CORS_ALLOWED_ORIGINS`, Gitea 는 `GITEA_ROOT_URL`.

6. **반영** — conf 만 바꿨으면 nginx 만 다시 읽히면 됩니다.

   ```bash
   docker compose exec webserver nginx -t && docker compose exec webserver nginx -s reload
   ```

   5번에서 `.env` 값을 바꿨다면 해당 컨테이너만 다시 만듭니다.

   ```bash
   docker compose up -d plane-api plane-web plane-live
   docker compose up -d gitea
   ```

   > ⚠️ 전체 `docker compose restart` 는 쓰지 마세요. 모든 서비스가 동시에 재시작하면서 app 이 내려간 순간 nginx 가 먼저 떠 `[emerg] host not found in upstream` 으로 한 번 죽을 수 있습니다(자동 재기동은 됩니다). 전체 재기동은 `stop` → `start` 순서로 하세요.
   >
   > ⚠️ `docker compose down -v` 도 쓰지 마세요. named volume(Plane 데이터 · Gitea 저장소 등)이 삭제됩니다.

7. **갱신 cron** — certbot 갱신은 nginx 이미지 안에 내장돼 있습니다(`docker/nginx/Dockerfile` 이 빌드할 때 crontab 에 등록). 호스트에 별도 cron 을 걸 필요가 **없습니다**. 확인: `docker compose exec webserver crontab -l`.

## Additional development item

- System integration between Jenkins, Gitea and Plane.
- Support docker-swarm, kubernetes
- docker and orchestration monitoring system
- backup and security system
- Support cloud such as AWS, GCM etc

## Community

- **Personal Website** : Owner's personal website is devspoon.com

## Partners and Users

- Lim Do-Hyun Owner Developer/project Manager, bluebamus@gmail.com  
  Personal github.io : [bluebamus.github.io]

<!-- Markdown link & img dfn's -->

[devspoon-web]: https://github.com/devspoons/devspoon-web
[Plane]: https://plane.so/
[Plane docs]: https://developers.plane.so/self-hosting/overview
[Jenkins]: https://en.wikipedia.org/wiki/Jenkins_(software)
[Gitea]: https://about.gitea.com/
[Gitea docs]: https://docs.gitea.com/installation/install-with-docker
[Harbor]: https://en.wikipedia.org/wiki/Harbor
[bluebamus.github.io]: https://bluebamus.github.io
