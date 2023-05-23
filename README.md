# Proj23

## Usage
```bash
./build_files.sh -d directory -t temperature

mpirun -np 8 lmp_mpi -v ns 2 iv r 50000 -in restart.lmp

./clean_files.sh -d directory
```
