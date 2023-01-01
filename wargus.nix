# run with nix-build -I nixpkgs=<local nixpkgs> wargus.nix
with import <nixpkgs> {}; 
wargus.override{ 
  #cdData = runCommand "gameData" { src = ../warcraft2/both/base; } "mkdir $out; cp -r $src/* $out";  
  #expansionData = runCommand "expansionData" { src = ../warcraft2/both/expansion; } "mkdir $out; cp -r $src/* $out";  
  cdData = builtins.path {
    path = "/home/test-user/warcraft2/base";
    name = "base";
  };
  expansionData = builtins.path {
    path = "/home/test-user/warcraft2/expansion";
  };
}
