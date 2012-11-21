#!/usr/bin/php
<?php
    define("DS", DIRECTORY_SEPARATOR);

    if(empty($argv[1]) || empty($argv[2])) {
        error("Please provide SOURCE adn DESTINATION");
    }

    $src = $argv[1];
    $dst = $argv[2];
    $tmpdst = "/tmp/src/";

    if(!is_dir($src)) error("Source $src does not exists");
    if(!is_dir($dst)) error("Dest $dst does not exists");

    if ($handle = opendir($src)) {
        while (false !== ($file = readdir($handle)))
        {
            $keynotexists = 0;
            $keymerged = 0;
            $srclang = NULL;
            $dstlang = NULL;

            $tmpfile = $tmpdst . DS . $file;

            if(!is_dir($tmpdst)) error("No temp dir $tmpdst found");

            if ($file != "." && $file != ".." && strtolower(substr($file, strrpos($file, '.') + 1)) == 'php')
            {
                info("Processing $file");

                //Including files one by one untill end from source
                $srcfile = $src . DS . $file;
                $dstfile = $dst . DS . $file;

                if(!file_exists($dstfile)) {
                    error("No dest file $dstfile exists");
                }

                include($srcfile);
                $srclang = $lang; unset($lang);
                include($dstfile);
                $dstlang = $lang; unset($lang);

                foreach($srclang as $k=>$v) {
                    $v = str_replace('\\\\\\', '',$v);
                    if(!array_key_exists($k, $dstlang)) {
                        info("Key: '$k' not found on $dstlang, copying");
                        $dstlang[$k] = $v;
                        $keynotexists++;
                    }else{
                        if($v != $dstlang[$k]) {
                            info("Value of a key '$k' is not the same as in destination, merging");
                            $dstlang[$k] = $v;
                            $keymerged++;
                        }
                    }
                }

                info("Merge of $file compleeted");

                if(empty($tmpfile)) error("Tmp file is empty");
                if(file_exists($tmpfile)) {
                    info("Temp file $tmpfile exists, recreating");
                    unlink($tmpfile);
                }

                if(!empty($dstlang)) {
                    file_put_contents($tmpfile, "<?php\n\$lang = array (\n",FILE_APPEND);
                    foreach($dstlang as $k=>$v) {
                        //$v = addslashes($v);
                        //$v = pg_escape_string($v);
                        $v = str_replace("'", "\\'", $v);
                        $v = str_replace("\\\\'", "\\'", $v);

                        //echo $v."\n";
                        file_put_contents($tmpfile, "\t'$k' => '$v',\n", FILE_APPEND);
                    }
                    file_put_contents($tmpfile, ');',FILE_APPEND);
                }
                unset($lang);
            }


        }
        closedir($handle);
    }

///// FUNCTIONS ////////
function error($msg) {
    echo "ERROR: $msg\n";
    exit;
}
function info($msg) {
    echo "INFO: $msg\n";
}


