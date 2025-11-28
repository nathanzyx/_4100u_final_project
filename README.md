# Study Communities Finder

Project By:
- Nathan Tandory (**Backend Lead**)
- Zayam Khan (**UI/UX & Navigation Lead**)
- Ryan Hastings (**Front End Lead**)
- Myron Lobo (**Technical Manager**)


## How to Run

1. Run your virtual device

2. Set directory to the base project 

    `
    cd <Path-To>/_4100u_final_project
    `

3. In powershell, execute `run_project.ps1`

    `
    .\run_project.ps1
    `

# Contributions

Each group member constributed the following

### **Nathan Tandory - Contributions**

**Created**
- **Backend**
    - `lib/client/`
        - `client_api.dart` (*created client-server connection*)
        - `client_services.dart` (*created client-side API calls*)
    - `lib/services/`
        - `app_notifier.dart` (*created base app notification system*)
    - **Server** `study_connect_server/`
        - `database.dart` (*updated SQL definitions, created database API methods*)
    - **Notifications** `lib/client/`
        - `notification_service.dart` (*created base notification service for the client*)
- **Data Classes** (`study_connect_shared/lib/models/`)
    - `user.dart` (*created user data model*)
- **App QOL**
    - `run_project.ps1`

**Modified**
- **Frontend**
    - **Pages** (`lib/pages/`) (*minor updates*)
        - `chat_page.dart`
        - `group_details_page.dart`
        - `home_page.dart`
    - **Widgets** (`lib/widgets/`) (*minor updates*)
        - `create_group.dart`
        - `create_session.dart`
        - `edit.dart`
- **Shared models** (`study_connect_shared/lib/models/`) (*minor additions*)
    - `chat_message.dart`
    - `group.dart`
    - `session.dart`


### **Zayam Khan - Contributions**

**Created**
- **Frontend**
    - **Pages** (`lib/pages/`)
        - `chat_page.dart` (*created chatting page*)
        - `group_details_page.dart` (*created group page*)
        - `home_page.dart` (*created home page*)
    - **Widgets** (`lib/widgets/`)
        - `create_group.dart` (*created group creation UI*)
        - `create_session.dart` (*created session creation UI*)
        - `edit.dart` (*created*)
    - **Services**
        - `tips.dart` (*created*)
- **Backend**
    - **Server** (`study_connect_server/`)
        - `database.dart` (*implemented initial database and methods*)
- **Data Classes** (`study_connect_shared/lib/models/`)
    - `chat_message.dart` (*created message data model*)
    - `group.dart` (*created group data model*)
    - `session.dart` (*created session data model*)

### **Ryan Hastings - Contributions**

**Modified**
- **Backend**
    - **Server** (`study_connect_server/`) (*minor fixes*)
        - `database.dart` (*bug fix*)

### **Myron Lobo - Contributions**

