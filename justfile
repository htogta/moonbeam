build: bootstrap

bootstrap: make-lua
  lua moonbeam.lua moonbeam.lua

make-lua:
  make all -C lua
