# Keycloack Test
This is a simple repo to show integration between an iOS app and keycloack.
This example is the same of [AppAuth](https://github.com/openid/AppAuth-iOS)
## 📂 Project structure

```text
.
├── docker-compose.yml
├── kc-realm
│   └── test-realm.json
├── KeycloackTest
│   ├── AppAuthViewController.swift
│   ├── AppDelegate.swift
│   ├── Assets.xcassets
│   ├── Base.lproj
│   ├── Info.plist
│   ├── SceneDelegate.swift
│   └── ViewController.swift
├── KeycloackTest.xcodeproj
│   ├── project.pbxproj
│   ├── project.xcworkspace
│   └── xcuserdata
└── README.md
```

## Preconditions
You should have up and running `keycloack` in local. You can use `docker-compose` and run `docker-compose up`.
Kycloack image use use `test-realm.json` file presente in repo to start keycloack in dev mode.
User credentials are:
- username: `test`
- password: `test`
