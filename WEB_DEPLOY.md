# 通过网址联机

这个项目可以发布成 Flutter Web 网页。朋友打开同一个网址后，进入“线上房间”，输入你的房间码就能联机。

## 1. 准备 Supabase

创建 Supabase 项目，复制这两个值：

- Project URL
- anon/public key

不要使用 service_role key。

## 2. 上传到 GitHub

如果项目还没有 Git 仓库，在项目目录运行：

```powershell
git init
git add .
git commit -m "Add online web deployment"
git branch -M main
git remote add origin https://github.com/你的用户名/你的仓库名.git
git push -u origin main
```

## 3. 发布网页

本项目已经把 Flutter Web 成品放在 `docs/` 文件夹。进入 GitHub 仓库：

Settings -> Pages -> Build and deployment -> Source

选择：

```text
Deploy from a branch
```

Branch 选择：

```text
main / docs
```

## 4. 等待发布完成

推送到 `main` 后，GitHub Pages 会自动发布 `docs/` 里的网页。发布成功后，Pages 页面会显示网址，通常类似：

```text
https://你的用户名.github.io/你的仓库名/
```

你和朋友打开这个网址，一个人创建房间，另一个人输入房间码加入。
