cmake_minimum_required(VERSION 2.8)
project(main)

set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -g -Wall -Werror -std=c11")

set(MAIN_SOURCE main.c parse.c cJSON.c list.c)
add_executable(main ${MAIN_SOURCE})
TARGET_LINK_LIBRARIES(main m)
#TARGET_LINK_LIBRARIES(main ${PROJECT_SOURCE_DIR}/libparse.a)