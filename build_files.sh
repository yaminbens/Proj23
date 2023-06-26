while getopts d:t:s flag
do
    case "${flag}" in
        d) directory=${OPTARG};;
        t) tmp=${OPTARG};;
        s) seed=${OPTARG};;
    esac
done

mkdir ${directory}
cd    ${directory}
mkdir plumed
mkdir log
mkdir dump
mkdir restart
mkdir colvar
mkdir data
mkdir fes
touch HILLS
cp ../baserun250/restart.${tmp}.50000 restart
cp ../baserun250/log.lammps log

##########################################################################

cat > "in.partitions" << EOF
    variable p_id world   0 # 1 2 3 4 5
EOF

cat > "in.temp" << EOF
    variable temperature equal ${tmp}
    variable tempDamp equal 0.1 # approx 0.1 ps
EOF

cat > "in.pressure" << EOF
    variable pressure equal 1.
    variable pressureDamp equal 10.0
EOF

cat > "in.seed" << EOF
    variable seed world ${seed} #74581 # 93734 12832 21934 57383 49172
EOF

cat > "in.box" << EOF
    variable        side equal 22.0
    variable        numAtoms equal 256
    variable        mass equal 22.98977
    region          box block 0 \${side} 0 \${side} 0 \${side}
    create_box      1 box
    create_atoms    1 random \${numAtoms} \${seed} box
    mass            1 \${mass}
    change_box      all triclinic
EOF

cat > "in.na" << EOF
    ### Argon Potential Parameters ###
    pair_style  eam/fs
    pair_coeff  * * ../Na_MendelevM_2014.eam.fs Na
EOF


cat > "in.setup" << EOF
    variable        out_freq equal 500
    variable        out_freq2 equal 25000
    neigh_modify    delay 10 every 1
    include         in.na
    timestep        0.002 # According to Frenkel and Smit is 0.001
    thermo          \${out_freq}
    thermo_style    custom step temp pe ke press density vol enthalpy atoms lx ly lz xy xz yz pxx pyy pzz pxy pxz pyz
    restart         \${out_freq2} restart/restart.\${temperature}
EOF

cat > "in.dump" << EOF
    dump         myDump all atom \${out_freq2} dump/dump\${temperature}.lammpstrj id type x y z
    dump_modify  myDump append yes
EOF

##########################################################################

cat > "plumed.dat" << EOF
RESTART

LOAD FILE=../../PRL-2017-PairEntropy/PairEntropy.cpp

PAIRENTROPY ...
 LABEL=s2
 ATOMS=1-256
 MAXR=0.7
 SIGMA=0.0125
... PAIRENTROPY

ENERGY LABEL=ene

VOLUME LABEL=vol

COMBINE ...
 ARG=ene,vol
 POWERS=1,1
 COEFFICIENTS=1.,0.060221409
 PERIODIC=NO
 LABEL=enthalpy
... COMBINE

COMBINE ...
 ARG=enthalpy
 POWERS=1
 COEFFICIENTS=0.004
 PERIODIC=NO
 LABEL=enthalpyPerAtom
... COMBINE

METAD ...
 LABEL=metad
 ARG=enthalpyPerAtom,s2
 SIGMA=0.2,0.1
 HEIGHT=2.5
 BIASFACTOR=30
 TEMP=${tmp}
 PACE=500
 GRID_MIN=-110,-10
 GRID_MAX=-90,-1
 GRID_BIN=500,500
 CALC_RCT
... METAD

PRINT STRIDE=500  ARG=* FILE=colvar/COLVAR

EOF
 
##########################################################################
    
cat > "restart.lmp" << EOF
echo both

include in.partitions
log log/log.lammps append

include in.temp
include in.pressure
include in.seed
units metal
atom_style full
box tilt large
read_restart restart/restart.\${temperature}.\${r}
include in.setup

# NVT
variable kenergy equal ke
variable penergy equal pe
variable pres equal press
variable tempera equal temp
variable dense equal density
variable entha equal enthalpy 

fix myat1 all ave/time 100 5 1000 v_kenergy v_penergy v_pres v_tempera v_dense v_entha file data/energy\${temperature}.dat

#timer           timeout 23:50:00 every 5000

include         in.dump

fix             1 all plumed plumedfile plumed.dat outfile plumed/plumed\${temperature}.out
fix             2 all nph &
                x \${pressure} \${pressure} \${pressureDamp} &
                y \${pressure} \${pressure} \${pressureDamp} &
                z \${pressure} \${pressure} \${pressureDamp} &
                xy 0.0 0.0 \${pressureDamp} &
                yz 0.0 0.0 \${pressureDamp} &
                xz 0.0 0.0 \${pressureDamp} &
                couple xyz
fix             3 all temp/csvr \${temperature} \${temperature} \${tempDamp} \${seed}
fix             4 all momentum 10000 linear 1 1 1 angular

variable 	steps equal \${ns}*500000 #1 ns
run           	\${steps} 

EOF
