## LocalでRailsメールテスト開発環境構築とメールの内容確認
前提:
- VirtualBox
- 仮想マシン上でpostfixとdovcotをつかいます
- ゲストOSはcentos7.2
- メールは仮想マシンから外にでない
- Railsは既に入っている

(参考)  
[閉じられたネットワーク向けのテスト用メールサーバーを構築する](https://yoshinorin.net/2016/08/07/local-mailserver/)  
上記サイトがわかりやすいです。セットアップは上記を見ればいいかも

### システムのアップデート

```bash
yum -y update
```

### SELinux無効

```bash
vi /etc/selinux/config
SELINUXTYPE=disabled
```


### Postfixの設定(送信用)
インストールして自動起動するようにします。

```bash
sudo yum -y install postfix
sudo service postfix start
sudo chkconfig postfix on
```

Postfixの設定を変更します。  
`vi /etc/postfix/main.cf`

```bash
# 自身のドメイン設定
mydomain = mail-server.test
myorigin = $mydomain

# ローカルホスト以外からも受け付けます
inet_interfaces = all

# ipv4しか使用しないため
inet_protocols = ipv4

# 宛先ドメインに自身のドメインを追加します
mydestination = $myhostname, localhost.$mydomain, localhost, mail-server.test

# 初めはローカルホストで動かすため
mynetworks = localhost

# メールボックスの形式設定
home_mailbox = Maildir/
```

設定反映のためにPostfixを再起動、

`service postfix restart`

- メールテスト用のアカウントを１つ作成

```bash
# user1というアカウントを作成します。
useradd user1 -s /sbin/nologin
# 任意のパスワード入力
passwd ****

# user1が書き込みできるようにします
chmod 777 /var/spool/mail

sudo yum -y install telnet

```

### Dovecot(POP3,IMAPサーバ)
```bash
# インストール
yum -y install dovecot

# 起動
service dovecot start

# 自動起動
chkconfig dovecot on

vi /etc/dovecot/dovecot.conf

```
- 設定ファイル

```bash
# 使用するプロトコル列挙
  protocols = imap pop3 lmtp

# IPv4のみ使用。v6へのバインドを行わない
  listen = *
```

`vi /etc/dovecot/conf.d/10-mail.conf`

```bash
# ファイルの場所を指定
  mail_location = maildir:~/Maildir

```

`vi /etc/dovecot/conf.d/10-auth.conf`

```bash
# 平文認証の許可
  disable_plaintext_auth = no

  auth_mechanisms = plain login
```

設定反映のため、再起動

```bash
service dovecot restart
```
### Railsの設定を確認します。
`view ./config/environments/development.rb`
```ruby
config.action_mailer.delivery_method = :smtp
config.action_mailer.smtp_settings = {
  address: "localhost",
  port: 25,
  enable_starttls_auto: false
}
```

### テスト実施/メールの内容確認
(宛先 user1@mail-server.testで)メール発信テストすると  
/home/user1/Maildir/newにファイルができます。  
(なければ/home/user1/Maildir/cur にはいってるかも)   

`su root -`して  

```bash
cd /home/user1/Maildir/new; chmod a+rw *; cp 対象mail /tmp/test1
exit;
```


`vi /tmp/test1`してファイルのbase64エンコード部分だけ別ファイルに切り出します。    
できたファイルは下記で開いてメールの内容を確認できます。

`cat /tmp/betsu_file | base64 -d `
