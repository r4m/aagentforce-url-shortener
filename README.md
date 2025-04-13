# URL Shortener in Salesforce with Public Redirect (Complete Guide)

This guide will walk you through creating an **internal URL shortening service** in Salesforce, including:

✅ Custom Object\
✅ Apex to generate short codes\
✅ Flow to create, retrieve, and return the short URL\
✅ Public-facing redirect page at `/s/{shortCode}`\
✅ LWC for automatic redirection

---

## 1. Create the Custom Object `Shortened_URL__c`

### Navigate to:

**Setup > Object Manager > Create > Custom Object**

### Set the following:

| Field           | Value                               |
| --------------- | ----------------------------------- |
| Label           | `Shortened URL`                     |
| Object Name     | `Shortened_URL`                     |
| Record Name     | `Auto Number` (e.g., `SHRT-{0000}`) |
| Enable features | API, Reports, Tabs, etc.            |

### Create these custom fields:

| API Name        | Type           | Description                                 |
| --------------- | -------------- | ------------------------------------------- |
| `Long_URL__c`   | URL            | The original full URL                       |
| `Short_Code__c` | Text (10)      | Generated short code (e.g., `a1f9c3`)       |
| `Short_URL__c`  | Formula (Text) | Formula to generate public-facing short URL |

Formula:

```text
"https://<YOUR_SITE>.my.site.com/sfpwebhook/s/" & Short_Code__c
```
where you must replace `<YOUR_SITE>` with your specific Salesforce org site.

![Create Custom Object](screenshots/1_Create%20the%20Custom%20Object%20Shortened_URL__c.png)

---

## 2. Apex Class to Generate `Short_Code__c`

> Important: To improve security, you can generate the short code using a UUID or a cryptographically secure random string instead of a predictable hash like MD5. This minimizes the risk of brute force or pattern-based attacks. Note: If you use a UUID, make sure to increase the length of the Short_Code__c field to at least 36 characters.

```apex
public class ShortURLFlowHelper {

    @InvocableMethod(label='Generate Short Code for URL')
    public static List<Output> generateShortCode(List<Input> inputs) {
        List<Output> results = new List<Output>();
        if (inputs != null && !inputs.isEmpty()) {
            String longUrl = inputs[0].longUrl;
            String code = EncodingUtil.convertToHex(
                Crypto.generateDigest('MD5', Blob.valueOf(longUrl))
            ).substring(0, 6);
            Output o = new Output();
            o.shortCode = code;
            results.add(o);
        }
        return results;
    }

    public class Input {
        @InvocableVariable(label='Long URL')
        public String longUrl;
    }

    public class Output {
        @InvocableVariable(label='Short Code')
        public String shortCode;
    }
}
```

![Apex Class to Generate Short Code](screenshots/2_Apex%20Class%20to%20Generate%20Short_Code__c.png)

---

## 3. Flow: Generate Short URL from LongURL (Input/Output)

### Flow Type: **Autolaunched Flow**

### Global Variables:

| Variable    | Type | Direction | Description                                 |
| ----------- | ---- | --------- | ------------------------------------------- |
| `LongURL`   | URL  | Input     | The long URL to shorten                     |
| `ShortCode` | Text | Output    | Generated short code (e.g., `a1f9c3`)       |
| `ShortURL`  | Text | Output    | Complete short URL (`https://.../s/a1f9c3`) |

### Flow Steps:

#### Step 1: **Invoke Apex Class**

- Type: Apex Action
- Class: `ShortURLFlowHelper.generateShortCode`
- Input: `LongURL` → `longUrl`
- Output: `shortCode` → `ShortCode`

#### Step 2: Create Record

- Map fields:
  - `Long_URL__c` = `LongURL`
  - `Short_Code__c` = `ShortCode`
- Save the record ID to `ShortenedRecordId`

#### Step3: Retrieve Record to Get 

- Type: Get Records
- Object: `Shortened_URL__c`
- Filter: `Id = ShortenedRecordId`
- Return only the first record
- Assign `Short_URL__c` to `ShortURL`

![Flow from LongURL 0](screenshots/3_Flow%20to%20Generate%20Short%20URL%20from%20LongURL%20_0.png)
![Flow from LongURL 1](screenshots/3_Flow%20to%20Generate%20Short%20URL%20from%20LongURL%20_1.png)
![Flow from LongURL 2](screenshots/3_Flow%20to%20Generate%20Short%20URL%20from%20LongURL%20_2.png)
![Flow from LongURL 3](screenshots/3_Flow%20to%20Generate%20Short%20URL%20from%20LongURL%20_3.png)
![Flow from LongURL 4](screenshots/3_Flow%20to%20Generate%20Short%20URL%20from%20LongURL%20_4.png)

---

## 4. Public Redirect Page

> Notice: you can you whatever site you prefer, even a newly created one. In my case I used the predefined `sfpwebhook` website.

1. Go to **Setup > All Sites > [your site with /s/ path] > Workspace > Builder**
2. Create a new page named `RedirectPage`
   - URL: `/redirect`
3. Add the `shortUrlRedirect` component
4. Publish the site

![Public Redirect Page 0](screenshots/4_Public%20Redirect%20Page_0.png)
![Public Redirect Page 1](screenshots/4_Public%20Redirect%20Page_1.png)

---

## 5. LWC for Automatic Redirection

### Prerequisites:

- [Salesforce CLI](https://developer.salesforce.com/tools/sfdxcli)
- Visual Studio Code
- Salesforce Extension Pack for VS Code

### Setup Steps:

```bash
sfdx force:project:create -n url-shortener
cd url-shortener
sfdx force:auth:web:login -a MyOrgAlias
```

Place your files in:

```
force-app/main/default/classes/
force-app/main/default/lwc/shortUrlRedirect/
```

Deploy:

```bash
sf project deploy start --source-dir force-app --target-org MyOrgAlias
```

### Apex Controller:

```apex
public without sharing class ShortUrlRedirectController {
    @AuraEnabled(cacheable=true)
    public static String findLongUrl(String shortCode) {
        List<Shortened_URL__c> urls = [
            SELECT Long_URL__c FROM Shortened_URL__c WHERE Short_Code__c = :shortCode LIMIT 1
        ];
        if (!urls.isEmpty()) {
            return urls[0].Long_URL__c;
        } else {
            throw new AuraHandledException('Short URL not found.');
        }
    }
}
```

### JavaScript: `shortUrlRedirect.js`

```js
import { LightningElement } from 'lwc';
import findLongUrl from '@salesforce/apex/ShortUrlRedirectController.findLongUrl';

export default class ShortUrlRedirect extends LightningElement {
    errorMessage;

    connectedCallback() {
        const path = window.location.pathname;
        const shortCode = path.split('/').pop();
        this.redirect(shortCode);
    }

    async redirect(code) {
        try {
            const url = await findLongUrl({ shortCode: code });
            window.location.href = url;
        } catch (e) {
            console.error('Redirect failed', e);
            this.errorMessage = e?.body?.message || 'Short URL not found.';
        }
    }
}
```

### HTML: `shortUrlRedirect.html`

```html
<template>
    <div class="redirect-container">
        <template if:true={errorMessage}>
            <p class="redirect-title" style="color: #d9534f;">{errorMessage}</p>
        </template>
        <template if:false={errorMessage}>
            <div class="spinner-wrapper">
                <div class="custom-spinner"></div>
            </div>
            <p class="redirect-title">Redirecting...</p>
            <p class="redirect-subtext">Please wait a moment</p>
        </template>
    </div>
</template>
```

### CSS: `shortUrlRedirect.css`

```css
.redirect-container {
    padding: 2rem;
    text-align: center;
}
.redirect-logo {
    width: 120px;
    margin-bottom: 1rem;
}
.spinner-wrapper {
    margin: 1rem auto;
}
.custom-spinner {
    border: 4px solid #1589ee;
    border-top: 4px solid transparent;
    border-radius: 50%;
    width: 40px;
    height: 40px;
    animation: spin 1s linear infinite;
    margin: 0 auto;
}
.redirect-title {
    font-size: 1.2rem;
    font-weight: 600;
    margin-top: 1rem;
}
.redirect-subtext {
    font-size: 0.9rem;
    color: #888;
}
@keyframes spin {
    0% { transform: rotate(0deg); }
    100% { transform: rotate(360deg); }
}
```

### Meta Files:

#### `shortUrlRedirect.js-meta.xml`

```xml
<LightningComponentBundle xmlns="http://soap.sforce.com/2006/04/metadata">
    <apiVersion>59.0</apiVersion>
    <isExposed>true</isExposed>
    <targets>
        <target>lightningCommunity__Page</target>
    </targets>
</LightningComponentBundle>
```

#### `ShortUrlRedirectController.cls-meta.xml`

```xml
<ApexClass xmlns="http://soap.sforce.com/2006/04/metadata">
    <apiVersion>59.0</apiVersion>
    <status>Active</status>
</ApexClass>
```

---

## 6. Set Permissions for Guest User and Agentforce Users

### Grant Apex Class Access

1. Go to **Setup > Digital Experiences > All Sites**
2. Click **Builder** next to your site
3. Click the gear icon > **General** > Open Site Settings
4. Click on the **Guest User Profile** link (e.g., `sfpwebhook Profile`) at the bottom of the modal window
5. Under **Apex Class Access**, click **Edit** and add `ShortUrlRedirectController`

### Grant Object and Field Permissions

1. In the **Guest User Profile** (e.g., `sfpwebhook Profile`) settings:

   - Go to **Object Settings > Shortened\_URL\_\_c**
   - ✅ Enable **Read Access** to the object
   - ✅ Ensure visibility for `Short_Code__c` and `Long_URL__c` fields

2. In the **ServiceAgent (Agentforce)** user's profile or assigned permission set:

   - Go to **Object Settings > Shortened\_URL\_\_c**
   - ✅ Enable **Read and Write Access** to the object
   - ✅ Ensure visibility for `Short_Code__c`, `Long_URL__c`, and `Short_URL__c` fields

![Guest User Profile 0](screenshots/5_Set%20Permissions%20for%20Guest%20User%20Profile_0.png)
![Guest User Profile 1](screenshots/5_Set%20Permissions%20for%20Guest%20User%20Profile_1.png)
![Guest User Profile 2](screenshots/5_Set%20Permissions%20for%20Guest%20User%20Profile_2.png)
![Guest User Profile 3](screenshots/5_Set%20Permissions%20for%20Guest%20User%20Profile_3.png)
![Guest User Profile 4](screenshots/5_Set%20Permissions%20for%20Guest%20User%20Profile_4.png)

### Set Sharing Settings (OWD)

1. Go to **Setup > Sharing Settings**
2. Find **Shortened\_URL\_\_c** object
3. Set:
   - **Default Internal Access**: Read/Write (or as required)
   - **Default External Access**: Public Read Only
4. Save

---

## Final Test

1. Run the Flow with any `LongURL` as input
2. You should get:
   - `ShortCode` → e.g., `a1f9c3`
   - `ShortURL` → `https://<YOUR_SITE>.my.site.com/sfpwebhook/s/a1f9c3`
3. Visit the link
4. Confirm that the redirect works correctly


