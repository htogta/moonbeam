local VERSION = "0.1.0"

function template_head()
  return [[
    #include <stddef.h>
    #include <stdlib.h>
    #include <stdio.h>
    
    // lua libraries
    #include "lua.h"
    #include "lualib.h"
    #include "lauxlib.h"
    
    // we implement a stringbuilder here to hold the Lua source code
    typedef struct {
      char* data;
      size_t count;
      size_t cap;
    } SBuilder;
    
    // heap-allocates string builder
    SBuilder* sbuilder_init() { 
      SBuilder* sb = (SBuilder*) malloc(sizeof(SBuilder));
      sb->count = 0;
      sb->cap = 1;
      sb->data = (char*) calloc(sb->cap, sizeof(char));
    
      if ((sb == NULL) || (sb->data == NULL)) {
        fprintf(stderr, "Failed to allocate memory for stringbuilder.\n");
        exit(71);
      }
    
      return sb;
    }
    
    // helper fn for appending a char to the stringbuilder
    void sbuilder_appendchar(SBuilder* sb, char c) {
      sb->data[sb->count] = c;
      sb->count++;
      
      if (sb->count > sb->cap) {
        sb->cap = sb->cap * 2; // growth factor of 2
        sb->data = (char*) realloc(sb->data, sb->cap * sizeof(char));
    
        if (sb->data == NULL) {
          fprintf(stderr, "Failed to allocate memory for stringbuilder.\n");
          exit(71);
        }
      }
    }
    
    // appends a string to the string builder
    void sbuilder_append(SBuilder* sb, const char* text) {
      while (*text != 0) {
        sbuilder_appendchar(sb, (char) *text);
        text++;
      }
    }
    
    // null-terminates the string, shrinks the string down to size 
    // and returns a pointer to it
    char* sbuilder_string(SBuilder* sb) {
      sbuilder_appendchar(sb, 0); // null terminate
    
      // shrink to size
      sb->data = (char*) realloc(sb->data, sb->count * sizeof(char));
    
      if (sb->data == NULL) {
        fprintf(stderr, "Failed to resize memory for stringbuilder.\n");
        exit(71);
      }
    
      // reset cap to count
      sb->cap = sb->count;
    
      return sb->data;
    }
    
    // deallocate the string builder
    void sbuilder_free(SBuilder* sb) {
      free(sb->data);
      free(sb);
    }
    
    int main(int argc, char* argv[]) {
    
      // create the lua source stringbuilder
      SBuilder* sb = sbuilder_init();
    
      // TODO LUA SOURCE CODE GETS INSERTED HERE
  ]]
end

function template_tail()
  return [[
    // use the lua library to run it
          char* source = sbuilder_string(sb);
          
          lua_State* L = luaL_newstate();
          luaL_openlibs(L);
        
          // push cli args into "arg" table
          lua_newtable(L);
          for (int i = 0; i < argc; i++) {
            lua_pushinteger(L, i);
            lua_pushstring(L, argv[i]);
            lua_settable(L, -3);
          }
          lua_setglobal(L, "arg");
          
          luaL_dostring(L, source);
          lua_close(L);
          
          // free it after running
          sbuilder_free(sb);
        
          return 0;
        }
  ]]
end

function c_escape(s)
  s = s:gsub("\\", "\\\\")   -- backslash first
  s = s:gsub("\"", "\\\"")   -- double quote
  s = s:gsub("'", "\\\'")    -- single quote (optional)
  s = s:gsub("\n", "\\n")    -- newline
  s = s:gsub("\r", "\\r")    -- carriage return
  s = s:gsub("\t", "\\t")    -- tab
  s = s:gsub("\0", "\\0")    -- NUL byte
  return s
end

-- write to luafile.c
function lua_to_c(src)
  c_src = template_head()

  for line in src:gmatch("[^\r\n]+") do
    c_src = c_src .. "\nsbuilder_append(sb, \"" .. c_escape(line) .. "\\n\");\n"
  end

  c_src = c_src .. template_tail()

  return c_src
end

-- TODO maybe call the c compiler from in here?

-- command line arg parsing region
function print_usage() print("Usage: moonbeam [-v] [-h] [-c] file.lua") end

local input_file = nil
local c_only = false
local help = false
local version = false

local argi = 1
while argi <= #arg do
  local a = arg[argi]
  if a == "-v" then
    version = true
  elseif a == "-h" then
    help = true
  elseif a == "-c" then
    c_only = true
  else
    if not input_file then
      input_file = a
    else
      print("Unexpected argument: " .. a)
      print_usage()
      os.exit(1)
    end
  end
  argi = argi + 1
end

if help then
  print_usage()
  print(" -h  print help text")
  print(" -v  print version info")
  print(" -c  output C code rather than compiling to executable")
  os.exit(0)
end

if version then
  print("moonbeam - convert a lua script to an exe, version " .. VERSION)
  os.exit(0)
end

if not input_file then print_usage() os.exit(1) end

-- now to actually read our input file
local f = io.open(input_file, "r")
if not f then print("Could not open file: " .. input_file) os.exit(1) end
local source = f:read("*a")
f:close()

-- convert to C code
local c_source = lua_to_c(source)

local cfilename = input_file:gsub("%.lua$", "") .. ".c"
local cfile = io.open(cfilename, "w")
cfile:write(c_source)
cfile:close()
if c_only then os.exit(0) end

-- otherwise, compile it with cc, remove the .c file, then exit
local command = string.format("cc -o %s %s", cfilename:gsub("%.c$", ""), cfilename)
command = command .. " lua/liblua.a -Ilua -lm -ldl"
local ret = os.execute(command) -- TODO how to handle this failing?

-- now to remove the .c file:
local ok, err = os.remove(cfilename)
if not ok then print("Failed to delete " .. cfilename) os.exit(1) end
