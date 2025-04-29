
## Installation
◾ Clone the Repository
```
git clone https://github.com/whalepiz/Drosera-Network/
cd Drosera-Network && chmod +x pc.sh && ./pc.sh
```
## Provide Information:
*The script will prompt you to enter the following details accurately:

🔸 Private Key: 

🔸 Public Address: 

🔸 Ethereum Holesky RPC URL: 
* Your RPC URL from Alchemy, QuickNode, or a public node. Press Enter to use the default (https://ethereum-holesky-rpc.publicnode.com).
* Example: https://eth-holesky.alchemyapi.io/v2/your-api-key
  
🔸 GitHub Email:

🔸 GitHub Username: 

## Check Node Liveness

🔸 Once the script execution is complete, navigate to the Drosera Dashboard at https://app.drosera.io/ to verify node activity. Look for green blocks, which indicate that your nodes are live and operational.

🔸 To monitor node performance in real-time, you can inspect the Docker logs using the following command:

```
cd ~/Drosera-Network
docker logs -f drosera-node
```
🔸 Check That you Have Green Block Log on your Dashboard ( Wait For At Least 1 Hour To Check )

![image](https://github.com/user-attachments/assets/0d1b0211-f970-45b2-9be2-3c4db6554d7c)

## Optional Command  [if required ]
```
pkill -f drosera-operator
cd ~
cd my-drosera-trap
source /root/.bashrc
drosera dryrun
cd ~
cd Drosera-Network
docker compose up -d
```




