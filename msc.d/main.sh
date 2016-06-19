#/bin/bash


main() {
    ms_import aloha log
    ms_log_setup


    local src="$1"
    local dst="${src%.ms}"
    if [ "$dst" == "$src" ]; then
        ms_die "Require a .ms input file."
    fi
    dst=$(basename $dst)

    if [ ! -f "$src" ]; then
        ms_die "No such file: '$src'."
    fi

    if [ -e "$MS_WORK_DIR/$dst" ]; then
        ms_die "Output file '$MS_WORK_DIR/$dst' already exists."
    fi

    if [ "$MS_COMPILED" == "no" ]; then
        mkdir $MS_TMP_DIR/$dst.d
        cp $MS_PROG_DIR/ms.sh $MS_TMP_DIR/$dst.sh
        cp -r $MS_PROG_DIR/ms.d $MS_TMP_DIR/$dst.d/.ms.d
        cp $src $MS_TMP_DIR/$dst.d/main.sh
        cd $MS_TMP_DIR && bash $dst.sh __make__
        cp $MS_TMP_DIR/$dst $MS_WORK_DIR/$dst.sh
    elif [ "$MS_COMPILED" == "yes" ]; then
        cp $MS_PROG_DIR/$MS_PROG $MS_TMP_DIR/
        cp $src $MS_TMP_DIR/main.sh
        cd $MS_TMP_DIR
        bash $MS_PROG __unmake__
        mv $MS_NS.sh $dst.sh
        rm $MS_NS.d/main.sh
        mv $MS_NS.d $dst.d
        mv main.sh $dst.d/main.sh
        bash $dst.sh __make__
        cp $dst $MS_WORK_DIR/$dst.sh
    fi
}
