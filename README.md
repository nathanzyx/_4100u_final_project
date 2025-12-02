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
    - `run_project.ps1` (*created powershell file to easily run app+server*)
- **Frontend**
    - **Pages** (`lib/pages/`)
        - `account_settings_page.dart` (*created account settings for updating common account variables*)

**Modified**
- **Frontend**
    - **Pages** (`lib/pages/`) (*minor updates*)
        - `chat_page.dart`
        - `group_details_page.dart`
        - `home_page.dart`
    - **Widgets** (`lib/widgets/`) (*updates*)
        - `create_group.dart` (*added location selection; user location or location specified by a popup map*)
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

**Created**
- **Frontend**
    - **Location Picker** (`lib/widgets/`)
        - `location_picker.dart` (*created full location picker dialog incorporating the flutter_map and latlong2 libraries with OpenStreetMap*)
- **Backend**
    - **Address Converter** (`lib/services/`)
        - `address_convert.dart` (*created service to convert a full address to coordinates using Nominatim (no longer used in current version)*)

**Modified**
- **Frontend**
    - **Home Page** (`lib/pages/`)
        - `home_page.dart` (*added method to calculate the distance between two pairs of coordinates, and used that to sort group list by distance from user (no longer exists in current version)*)
    - **Group Create/Edit** (`lib/widgets`)
        - `create_group.dart` (*split location field into four separate fields (address, city, state, country) and consolidated them into one location string on save (no longer exists in current version). Was intended to be used with address converter*)
        - `edit.dart` (*split location field into four separate fields (address, city, state, country) and consolidated them into one location string on save (no longer exists in current version). Was intended to be used with address converter*)
- **Backend**
    - **Client Services** (`lib/services/`) (*updates*)
        - `client_services.dart` (*added user coordinate support*)
    - **Server** (`study_connect_server/`) (*minor fixes and updates*)
        - `database.dart` (*bug fix*)
        - `database.dart` (*added coordinate columnns to relevant tables and updated related database methods accordingly*)
        - `study_connect_server.dart` (*added backend integration to location picker, user coordinates, and group coordinates*)
    - **Models** (`study_connect_shared/`) (*updates*)
        - `user.dart` (*added coordinate attributes and updated related methods accordingly*)
        - `group.dart` (*added coordinate attributes and updated related methods accordingly*)

### **Myron Lobo - Contributions**

**Created**
- **Frontend**
    - **Membership System** (`lib/pages/`)
        - `group_details_page.dart` (*added full join/leave group system, dynamic membership banner, conditional UI elements*)
    - **Session Membership Design** (`lib/pages/`)
        - `group_details_page.dart` (*planned structure for join/leave session UI and logic*)
- **Project Structure & Documentation**
    - (*improved documentation consistency and supported frontend organization*)

**Modified**
- **Frontend** (`lib/pages/`)
    - `group_details_page.dart` (*membership logic, UI updates, conditional FAB and chat visibility*)
    - `home_page.dart` (*UI behavior adjustments related to membership flow*)
    - `chat_page.dart` (*minor UI/usability improvements*)
- **Widgets** (`lib/widgets/`)
    - `create_session.dart` (*integration updates with session list*)
    - `create_group.dart` (*minor consistency fixes*)
