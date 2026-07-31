<div align="center">

<img src="https://capsule-render.com/api?type=waving&color=0:0A2540,100:2DD4BF&height=220&section=header&text=Trimitha%20Admin%20System&fontSize=42&fontColor=ffffff&animation=fadeIn&fontAlignY=38&desc=Website%20%2B%20Backend%20%2B%20Mobile%20Admin%20App&descAlignY=58&descSize=18" width="100%" alt="header banner"/>

<a href="https://github.com">
  <img src="https://readme-typing-svg.demolab.com?font=Poppins&weight=600&size=22&pause=1200&color=2DD4BF&center=true&vCenter=true&width=650&lines=Google+Apps+Script+%E2%80%A2+Sheets+%E2%80%A2+Drive;No+Firebase+backend+%E2%80%94+Firebase+used+only+for+push;Flutter+Admin+App+%2B+Live+Website+%2B+Blog+Engine;Contact+Forms+%E2%80%A2+Blog+CMS+%E2%80%A2+Real-time+Notifications" alt="typing banner" />
</a>

<br/>

![Flutter](https://img.shields.io/badge/Flutter-3.x-2DD4BF?style=for-the-badge&logo=flutter&logoColor=white&labelColor=0A2540)
![Dart](https://img.shields.io/badge/Dart-3.x-2DD4BF?style=for-the-badge&logo=dart&logoColor=white&labelColor=0A2540)
![Apps Script](https://img.shields.io/badge/Backend-Google_Apps_Script-2DD4BF?style=for-the-badge&logo=google&logoColor=white&labelColor=0A2540)
![Firebase](https://img.shields.io/badge/Push_Only-Firebase_Cloud_Messaging-2DD4BF?style=for-the-badge&logo=firebase&logoColor=white&labelColor=0A2540)
![License](https://img.shields.io/badge/License-Private-2DD4BF?style=for-the-badge&labelColor=0A2540)

<img src="https://capsule-render.com/api?type=rect&color=0:0A2540,100:141B2E&height=2&width=1000" width="100%" alt="divider"/>

</div>

## 📖 What this is

A complete personal admin system built entirely on **Google Apps Script +
Google Sheets + Google Drive** — no traditional server, no external
database. It has three parts that all talk to the same backend:

| Part | What it does |
|---|---|
| 🌐 **Website** | 4 contact-form pages (`contact.html`, `index.html`, `portfolio.html`, `coo.html`) + a fully dynamic blog (`blog.html`) with search, categories, pagination, and a featured post |
| ⚙️ **Backend** | One `Code.gs` file — REST-style API for auth, contact forms, blog CRUD, image upload, notifications, and push delivery |
| 📱 **Mobile App** | A Flutter admin app — Login, Dashboard, Forms Data, Blog Management, Notifications (with real push), and Settings |

<div align="center">
<img src="https://capsule-render.com/api?type=rect&color=0:0A2540,100:141B2E&height=2&width=1000" width="100%" alt="divider"/>
</div>

## ✨ Features

<table>
<tr>
<td width="33%" valign="top">

### 🌐 Website
- 4 contact forms → auto-routed to the right sheet
- Honeypot + rate-limit + duplicate-detection spam protection
- Dynamic blog engine (search, categories, pagination, featured post, related posts)
- Views counter per post
- Dark-mode toggle, responsive design

</td>
<td width="33%" valign="top">

### ⚙️ Backend (`Code.gs`)
- Token-based admin auth (hashed password)
- Contact + blog CRUD, all via one Web App URL
- Image upload straight to Google Drive
- Self-healing setup (`setupProject()`)
- Script-cache layer for faster repeat reads
- Push notifications via FCM (backend-triggered)

</td>
<td width="33%" valign="top">

### 📱 Mobile App
- Dark navy/teal Material 3 theme, Poppins + Inter typography
- Dashboard with live stat cards
- Forms Data: search, filter, star, delete, share
- Blog Management: create/edit/publish, image picker
- Notifications: unread badge + **push even when fully closed**
- Settings: change password, CSV export, logout

</td>
</tr>
</table>

<div align="center">
<img src="https://capsule-render.com/api?type=rect&color=0:0A2540,100:141B2E&height=2&width=1000" width="100%" alt="divider"/>
</div>

## 🏗️ Architecture

```mermaid
flowchart LR
    subgraph Website
        A[contact.html]
        B[index.html / portfolio.html / coo.html]
        C[blog.html]
    end

    subgraph MobileApp[📱 Flutter Admin App]
        D[Login / Dashboard]
        E[Forms Data]
        F[Blog Management]
        G[Notifications]
    end

    A & B --> H
    C --> H

    H([⚙️ Code.gs<br/>Web App]) --> I[(Google Sheets<br/>Master + Blogs)]
    H --> J[(Google Drive<br/>Blog Images)]
    H -. push .-> K([🔥 Firebase Cloud Messaging<br/>delivery only])
    K -. notification .-> MobileApp

    D & E & F & G --> H

    style H fill:#0A2540,stroke:#2DD4BF,color:#fff
    style K fill:#141B2E,stroke:#2DD4BF,color:#fff
    style I fill:#141B2E,stroke:#2DD4BF,color:#fff
    style J fill:#141B2E,stroke:#2DD4BF,color:#fff
```

> Firebase appears in exactly one place: delivering push notifications.
> Every other part of the system — auth, data, images, blog content — is
> Google Apps Script, Sheets, and Drive.

<div align="center">
<img src="https://capsule-render.com/api?type=rect&color=0:0A2540,100:141B2E&height=2&width=1000" width="100%" alt="divider"/>
</div>

## 📂 Project structure

```
├── website/
│   ├── contact.html
│   ├── index.html
│   ├── portfolio.html
│   ├── coo.html
│   └── blog.html
│
├── backend/
│   └── Code.gs                    # entire Apps Script backend
│
└── mobile_app/                    # Flutter project (personal_admin_app)
    ├── pubspec.yaml
    ├── assets/icon/                # app logo → flutter_launcher_icons
    └── lib/
        ├── main.dart
        ├── theme/app_theme.dart
        ├── models/                 # Contact, Blog
        ├── services/                # api_service, notification_service, push_service
        ├── screens/                 # login, dashboard, forms_data, blog_management,
        │                             # notifications, settings, app_shell...
        └── widgets/                  # contact_card, blog_card, dashboard_card...
```

<div align="center">
<img src="https://capsule-render.com/api?type=rect&color=0:0A2540,100:141B2E&height=2&width=1000" width="100%" alt="divider"/>
</div>

## 🚀 Getting started

Full step-by-step guides (written for zero prior experience) live
alongside this file:

| Guide | Covers |
|---|---|
| `SETUP_GUIDE.md` | Deploying `Code.gs`, connecting the website pages |
| `MOBILE_SETUP_GUIDE.md` | Installing Flutter, running the app, login |
| `PUSH_NOTIFICATIONS_SETUP.md` | Firebase project setup for push delivery |

**Quick version:**

```bash
# 1. Backend
#    Paste Code.gs into script.google.com → run setupProject() once →
#    Deploy as Web App → Who has access: Anyone → copy the /exec URL

# 2. Website
#    Paste the Web App URL + API key into each HTML file's API_CONFIG block

# 3. Mobile app
cd mobile_app
flutter pub get
flutter run
```

Default login (change immediately via `setMyPassword()` in the script
editor): `admin` / `ChangeMe123!`

<div align="center">
<img src="https://capsule-render.com/api?type=rect&color=0:0A2540,100:141B2E&height=2&width=1000" width="100%" alt="divider"/>
</div>

## 🛠️ Tech stack

<div align="center">

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=flat-square&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=flat-square&logo=dart&logoColor=white)
![Google Apps Script](https://img.shields.io/badge/Apps_Script-4285F4?style=flat-square&logo=google&logoColor=white)
![Google Sheets](https://img.shields.io/badge/Sheets-34A853?style=flat-square&logo=googlesheets&logoColor=white)
![Google Drive](https://img.shields.io/badge/Drive-FFCA28?style=flat-square&logo=googledrive&logoColor=black)
![Firebase](https://img.shields.io/badge/FCM_(push_only)-FFCA28?style=flat-square&logo=firebase&logoColor=black)
![HTML5](https://img.shields.io/badge/HTML5-E34F26?style=flat-square&logo=html5&logoColor=white)
![Tailwind](https://img.shields.io/badge/Tailwind_CSS-06B6D4?style=flat-square&logo=tailwindcss&logoColor=white)

</div>

<div align="center">
<img src="https://capsule-render.com/api?type=waving&color=0:2DD4BF,100:0A2540&height=120&section=footer" width="100%" alt="footer banner"/>
</div>
