I used Salt to set everything up on a remote server. On your home machine:

curl -L http://bootstrap.saltstack.org | sudo sh -s -- -M -N

On your remote server (minion):

wget -O - http://bootstrap.saltstack.org | sudo sh

Then edit the /etc/salt/minion file to point to your home server, and be
sure to open up ports 4505 and 4506 on your router.

Then we want to have our formulas linked up:
sudo ln -s /home/justinvf/github/justinvf/algorithm-shop/20140115-fraud-detection/file_root /srv/salt/survey
