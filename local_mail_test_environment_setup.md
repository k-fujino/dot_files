# Railsメールテスト準備手順
前提:
- VirtualBox
- ゲストOSはcentos7.2
- メールは仮想マシン内だけで完結したい
- 仮想マシン内でpostfixとdovcotをつかう

### システムのアップデート
```
yum -y update
```

### SELinux無効
vi /etc/selinux/config
SELINUXTYPE=disabled

 ※ファイアウォールが有効なら穴は開けておくこと

###Postfixの設定
```
sudo yum -y install postfix
sudo service postfix start
sudo chkconfig postfix on

#設定変更
vi /etc/postfix/main.cf
```

```
//自身のドメイン設定
mydomain = mail-server.test
myorigin = $mydomain

//ローカルホスト以外からも受け付ける
inet_interfaces = all

//ipv4しか使用しないため
inet_protocols = ipv4

//宛先ドメインに自身のドメインを追加
mydestination = $myhostname, localhost.$mydomain, localhost, mail-server.test

//初めはローカルホストで動かすため
mynetworks = localhost

//メールボックスの形式設定
home_mailbox = Maildir/

```

### 設定反映のためにPostfixを再起動
```
service postfix restart
```

### メールテスト用のアカウントを2つ作成します。

```
//user1というアカウントを作成する。
useradd user1 -s /sbin/nologin
//任意のパスワード入力
passwd ****

//user1が書き込みできるようにする
chmod 777 /var/spool/mail

sudo yum -y install telnet

```

## Dovecot
```
//インストール
yum -y install dovecot

//起動
service dovecot start

//自動起動
chkconfig dovecot on

vi /etc/dovecot/dovecot.conf

```
### 設定ファイル
```

  //使用するプロトコル列挙
  protocols = imap pop3 lmtp

  //IPv4のみ使用。v6へのバインドを行わない
  listen = *
```

```
vi /etc/dovecot/conf.d/10-mail.conf

  //ファイルの場所を指定
  mail_location = maildir:~/Maildir

```
```
vi /etc/dovecot/conf.d/10-auth.conf

  //平文認証の許可
  disable_plaintext_auth = no

  auth_mechanisms = plain login
```

設定反映のため、再起動します。
```
service dovecot restart
```

### テスト実施
(宛先 user1@mail-server.test)メール発信テストをすると
/home/user1/Maildir/cur あるいは
/home/user1/Maildir/newにファイルができる
su root -して
ファイルのbase64エンコード部分だけ別ファイルに切り出し下記で開いて内容確認
```
cat /tmp/betu_file | base64 -d
```
