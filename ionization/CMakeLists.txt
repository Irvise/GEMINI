add_library(ionization ionization.f90 glow_dummy.f90)
target_link_libraries(ionization PRIVATE neutral const mpimod)
set_target_properties(ionization PROPERTIES Fortran_MODULE_DIRECTORY ${CMAKE_BINARY_DIR})

if(useglow)
  include(${PROJECT_SOURCE_DIR}/cmake/glow.cmake)

  add_library(ionization_glow ionization.f90 glow_run.F90)
  target_link_libraries(ionization_glow PRIVATE neutral const mpimod cglow)
  set_target_properties(ionization_glow PROPERTIES Fortran_MODULE_DIRECTORY ${CMAKE_BINARY_DIR})
  target_include_directories(ionization_glow PRIVATE ${ncarglow_BINARY_DIR}/src)
  target_compile_definitions(ionization_glow PRIVATE DATADIR="build/_deps/ncarglow-src/data/")
endif(useglow)

add_library(precipBCs boundary_conditions/precipBCs_mod.f90)
target_link_libraries(precipBCs PRIVATE const grid io interp temporal timeutils)
target_compile_options(precipBCs PRIVATE ${FFLAGS})
set_target_properties(precipBCs PROPERTIES Fortran_MODULE_DIRECTORY ${CMAKE_BINARY_DIR})