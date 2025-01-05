---
title: "How to Run a React Development Server with HTTPS"
description: "Now your React app is securely running with HTTPS, streamlining local development with minimal setup!"
date: 2025-01-05T00:10:45+02:00
tags : ["react", "npm", "ssl"]
highlight: true
highlightLang: ["cs", "js"]
image: "splashscreen.jpg"
isBlogpost: true
---


**How to Run a React Development Server with HTTPS Using a Custom Script**

The development server used by `npm start` (powered by a Node.js-based server) supports HTTPS by default. However, web browsers often complain about the default certificate, making development frustrating. In this post, I will show you how to prepare and configure a trusted certificate that works seamlessly, providing an automated, cross-platform solution to integrate HTTPS into your React app.


### **Step-by-Step Guide**

#### 1. **Install Required Tools**
- Ensure `dotenv` npm package is installed.
- Install the .NET SDK to access `dev-certs` command. [Download here](https://dotnet.microsoft.com/download).

#### 2. **Create the Script**
Add a file named `set-ssl.js` to your project and paste the following code:

```javascript
const path = require("path");
const os = require("os");
const fs = require("fs");
const { execSync } = require("child_process");

const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), "https-cert-"));
const certFile = path.join(tempDir, "localhost.crt");
const keyFile = path.join(tempDir, "localhost.key");

try {
    console.log("Generating new development certificate...");
    execSync(`dotnet dev-certs https -ep ${certFile} --no-password --format PEM --trust`, { stdio: "inherit" });

    const eol = os.EOL;
    const envFilePath = path.join(process.cwd(), ".env.development.local");
    let envContent = "";

    if (fs.existsSync(envFilePath)) {
        console.log("Updating existing .env.development.local file...");
        const existingContent = fs.readFileSync(envFilePath, { encoding: "utf8" });
        const lines = existingContent.split(eol);
        const updatedLines = lines.map(line => {
            if (line.startsWith("HTTPS=")) return `HTTPS=true`;
            if (line.startsWith("SSL_CRT_FILE=")) return `SSL_CRT_FILE=${certFile}`;
            if (line.startsWith("SSL_KEY_FILE=")) return `SSL_KEY_FILE=${keyFile}`;
            return line;
        });
        if (!updatedLines.some(line => line.startsWith("HTTPS="))) {
            updatedLines.push(`HTTPS=true`);
        }
        if (!updatedLines.some(line => line.startsWith("SSL_CRT_FILE="))) {
            updatedLines.push(`SSL_CRT_FILE=${certFile}`);
        }
        if (!updatedLines.some(line => line.startsWith("SSL_KEY_FILE="))) {
            updatedLines.push(`SSL_KEY_FILE=${keyFile}`);
        }
        envContent = updatedLines.join(eol);
    } else {
        console.log("Creating new .env.development.local file...");
        envContent = `HTTPS=true${eol}SSL_CRT_FILE=${certFile}${eol}SSL_KEY_FILE=${keyFile}${eol}`;
    }

    fs.writeFileSync(envFilePath, envContent, { encoding: "utf8" });
    console.log("Certificate paths and HTTPS setting written to .env.development.local:");
    console.log(envContent);
} catch (error) {
    console.error("Failed to generate or trust the certificate:", error);
    process.exit(1);
}

```

#### 3. **Add the Script to `package.json`**
Include the script as a separate job in your `package.json` file:

```json
"scripts": {
  "ssl": "node set-ssl.js",
  "start": "react-scripts start"
}
```

#### 4. **Run the Script**
Generate and configure the certificate by running:
```bash
npm run ssl
```

This will:
- Create a new certificate in a temporary directory.
- Trust the certificate on your system.
- Write or update `.env.development.local` with the necessary HTTPS settings.

#### 5. **Start the Development Server**
Once the `.env.development.local` file is updated, start your React development server:
```bash
npm start
```

Now your React app is securely running with HTTPS, streamlining local development with minimal setup!


### **Why Use `.env.development.local`?**
The `.env.development.local` file is part of the environment variable configuration mechanism commonly used in React projects. It allows you to define environment-specific variables for your local development setup. This file:
- Is automatically read by the React development server when using `dotenv`.
- The `.local` suffix means that it keeps settings specific to local environment and it should not be committed to version control. Ensure `.gitignore` includes `.env.development.local` (this is the default in most React projects).

The `dotenv` package, which comes bundled with `react-scripts`, handles the parsing and loading of these environment variables into your application. If you’re not using `react-scripts`, you can install it manually:
```bash
npm install dotenv
```