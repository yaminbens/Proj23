# Proj23

## Usage
```bash
./build_files.sh -d metadNa -t 350 ; cd metadNa

mpirun -np 8 lmp_mpi -v ns 120 -v r 40050000 -in restart.lmp

./clean_files.sh -d directory
```
