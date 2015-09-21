# A script which can be run in /home/svnsvn/myGitRepositories to go into each 
# mirrored GitHub repo & run git fetch

for D in *
do
   echo $D
   cd $D
   pwd
    sudo git fetch
   cd -
done


