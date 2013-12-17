MultiAgentWaterMngt
===================
Multi-agent simulation model to support water distribution network partitioning using NetLogo

Author: Saeed Hajebi

How to cite: Hajebi, S., Barrett, S., Clarke, A. and Clarke, S., 
  'Multi-agent simulation to support water distribution network partitioning', 
  in 27th European Simulation and Modelling Conference - ESM’2013, Lancaster University, UK.
  

How to use:
Download the EpanetExport tool (https://github.com/saeed-hajebi/EpanetExport), 
create the necessary files using it (see the related Readme file), 
download and copy the WaterManagement.nlogo in the same directory as the created files. 
Open WaterManagement.nlogo file, type the EPANET input (*.inp) file name (without .inp) into the file_name box. 
Use setup, import-network, cluster, and negotiate-clusters in order.
You may need to use sclaing-factor if the geographic scale of the network is large. 
  It is tricky and needs some try and error, and sometimes needs changing the settings 
  of NetLogo to make it accomodate the size of the network.
  
Note: To run this model, you need to install the NetLogo Network extension. Just download it from https://github.com/downloads/NetLogo/NW-Extension/nw-ext-beta-0.02.zip, unzip it and put the nw directory to your /extensions of your NetLogo installation path. (e.g in Windowos it is: C:\Program Files (x86)\NetLogo 5.0.4\extensions).
