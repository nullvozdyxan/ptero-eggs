# Sigma Productions – Pterodactyl & Pelican Eggs

This repository contains **Pterodactyl / Pelican eggs** maintained by **Sigma Productions**, providing preconfigured setups for **web hosting** (with Python support).  

---

## 📦 Available Eggs

### 🌐 Pterodactyl Webhost Egg
Easily deploy a web server with Python support.

#### 🔧 How to Use:
1. Download the JSON egg file from the releases page.
2. Import the egg into your **Pterodactyl panel**.
3. Create a new server.  
4. Install **Composer** packages either during setup or afterward.
5. Access your server via the assigned IP and port.  
6. (Optional) Use a custom domain by setting up a **reverse proxy** on the host.

#### 📝 Disable Logs from Console:
To remove access/error logs from console output:
- Open `nginx/conf.d/default.conf`
- Uncomment these lines:
  ```nginx
  #access_log /home/container/naccess.log;
  #error_log  /home/container/nerror.log error;
  ```



## 📄 License

- Webhost Egg originally forked & edited from [tenten8401/pterodactyl-nginx](https://gitlab.com/tenten8401/pterodactyl-nginx)  
- Provided under the [MIT License](LICENSE).  

© 2024–2025 **Sigma Productions**. All rights reserved.  