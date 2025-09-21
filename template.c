// this C file gets used like a "template" - basically the lua source
// is inserted into this C file line-by-line as sbuilder_append() statements
// before calling upon the lua interpreter to run it

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
  sbuilder_append(sb, "print(\"this is lua code!\")\n");

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
