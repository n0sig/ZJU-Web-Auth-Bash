#!/bin/bash

_PADCHAR="="
_ALPHA="LVoJPiCN2R8G90yg+hmFHuacZ1OWMnrsSTXkYpUq/3dlbfKwv6xztjI7DeBE45QA"
INIT_URL="https://net.zju.edu.cn/"
GET_CHALLENGE_API="https://net.zju.edu.cn/cgi-bin/get_challenge"
SRUN_PORTAL_API="https://net.zju.edu.cn/cgi-bin/srun_portal"
N='200'
TYPE='1'
ENC="srun_bx1"

function ordat() {
    local msg="$1"
    local idx="$2"
    if [[ ${#msg} -gt idx ]]; then
        printf "%d" "'${msg:$idx:1}"
    else
        echo 0
    fi
}

function chr() {
  printf \\$(printf '%03o' $1)
}

function sencode() {
    local msg="$1"
    local key="$2"
    local l=${#msg}
    local pwd=()
    for ((i=0; i<l; i+=4)); do
        pwd+=($(($(ordat "$msg" "$i") + $(ordat "$msg" $((i+1))) * 256 + $(ordat "$msg" $((i+2))) * 65536 + $(ordat "$msg" $((i+3))) * 16777216)))
        true
    done
    if [[ "$key" == "true" ]]; then
        pwd+=($l)
    fi
    echo -n "${pwd[@]}"
}

function lencode() {
    local msg=($@)
    local l=${#msg[@]}
    local output=()
    for ((i=0; i<l; i++)); do
        output+=($((msg[$i] & 0xff)))
        output+=($((msg[$i] >> 8 & 0xff)))
        output+=($((msg[$i] >> 16 & 0xff)))
        output+=($((msg[$i] >> 24 & 0xff)))
    done
    echo -n "${output[@]}"
}

function get_xencode() {
    local msg="$1"
    local key="$2"
    if [[ -z "$msg" ]]; then
        echo -n ""
        return
    fi
    local pwd=($(sencode "$msg" true))
    local pwdk=($(sencode "$key" false))
    if [[ ${#pwdk[@]} -lt 4 ]]; then
        local n=${#pwdk[@]}
        for ((i=n; i<4; i++)); do
            pwdk+=(0)
        done
    fi
    local n=$(( ${#pwd[@]} - 1 ))
    local z=${pwd[$n]}
    local c=$((0x86014019 | 0x183639A0))
    local q=$((6 + 52 / (n + 1)))
    local d=0
    while ((q > 0)); do
        d=$(( d + c & (0x8CE0D9BF | 0x731F2640) ))
        local e=$((d >> 2 & 3))
        local p=0
        while ((p < n)); do
            local y=${pwd[$((p + 1))]}
            local m=$(( z >> 5 ^ y << 2 ))
            m=$(( m + ((y >> 3 ^ z << 4) ^ (d ^ y)) ))
            m=$(( m + (pwdk[$((p & 3)) ^ e] ^ z) ))
            pwd[$p]=$(( pwd[$p] + m & (0xEFB8D130 | 0x10472ECF) ))
            z=${pwd[$p]}
            ((p++))
        done
        local y=${pwd[0]}
        local m=$(( z >> 5 ^ y << 2 ))
        m=$(( m + ((y >> 3 ^ z << 4) ^ (d ^ y)) ))
        m=$(( m + (pwdk[$((p & 3)) ^ e] ^ z) ))
        pwd[$n]=$(( pwd[$n] + m & (0xBB390742 | 0x44C6F8BD) ))
        z=${pwd[$n]}
        ((q--))
    done
    lencode "${pwd[@]}"
}

function get_base64() {
  local s=($@)
  local x=""
  local imax=$(( ${#s[@]} - ${#s[@]} % 3 ))
  if [[ ${#s[@]} -eq 0 ]]; then
    echo ""
    return
  fi
  for ((i=0; i<imax; i+=3)); do
    local b10=$(( ${s[$i]} * 65536 + ${s[$((i + 1))]} * 256 + ${s[$((i + 2))]} ))
    x="${x}${_ALPHA:$((b10 >> 18)):1}"
    x="${x}${_ALPHA:$(((b10 >> 12) & 63)):1}"
    x="${x}${_ALPHA:$(((b10 >> 6) & 63)):1}"
    x="${x}${_ALPHA:$((b10 & 63)):1}"
  done
  local i=$imax
  if [[ $((${#s[@]} - imax)) -eq 1 ]]; then
    local b10=$(( ${s[$i]} << 16 ))
    x="${x}${_ALPHA:$((b10 >> 18)):1}${_ALPHA:$(( (b10 >> 12) & 63 )):1}${_PADCHAR}${_PADCHAR}"
  elif [[ $((${#s[@]} - imax)) -eq 2 ]]; then
    local b10=$(( ${s[$i]} << 16 | ${s[$((i + 1))]} << 8 ))
    x="${x}${_ALPHA:$((b10 >> 18)):1}${_ALPHA:$(( (b10 >> 12) & 63 )):1}${_ALPHA:$(( (b10 >> 6) & 63 )):1}${_PADCHAR}"
  fi
  echo $x
}

function get_chksum() {
    local chkstr="$token$username$token$hmd5$token$ac_id$token$ip$token$N$token$TYPE$token$i"
    echo -n "$chkstr"
}

function get_info() {
    local info_temp="{\"username\":\"$username\",\"password\":\"$password\",\"ip\":\"$ip\",\"acid\":\"$ac_id\",\"enc_ver\":\"$ENC\"}"
    echo "$info_temp" | sed 's/ //g'
}

function init() {
    echo 'Performing ZJU web auth...'
    local init_res=$(curl -s -L $INIT_URL)
    ac_id=$(echo "$init_res" | awk -F 'value=' '/ac_id/ {print $2}' | awk -F '"' '{print $2}')
    ip=$(echo "$init_res" | awk -F 'value=' '/user_ip/ {print $2}' | awk -F '"' '{print $2}')
    randnum=$(shuf -i 1-12345678901234567890 -n 1)
    echo "ip: $ip"
}

function get_token() {
    local params="callback=jQuery${randnum}_$(($(date +%s%N)/1000000))&username=$username&ip=$ip&_=$(($(date +%s%N)/1000000))"
    local res=$(curl -s -L "$GET_CHALLENGE_API?$params")
    token=$(echo "$res" | awk -F 'challenge":"' '{print $2}' | awk -F '"' '{print $1}')
}

function preprocess() {
    i=$(get_info)
    i="{SRBX1}$(get_base64 $(get_xencode "$i" "$token"))"
    hmd5=$(echo -n "$password" | openssl dgst -md5 -hmac "$token" | awk '{print $2}')
    chksum=$(echo -n "$(get_chksum)" | openssl dgst -sha1 | awk '{print $2}')
}

function login() {
    i=$(echo -n "$i" | sed 's/{/%7B/g' | sed 's/}/%7D/g' | sed 's/:/%3A/g' | sed 's/+/%2B/g' | sed 's/\//%2F/g' | sed 's/=/%3D/g' | sed 's/,/%2C/g' | sed 's/ /+/g')
    local params="callback=jQuery${randnum}_$(($(date +%s%N)/1000000))&action=login&username=$username&password=%7BMD5%7D$hmd5&ac_id=$ac_id&ip=$ip&chksum=$chksum&info=$i&n=$N&type=$TYPE&os=windows+10&name=windows&double_stack=0&_=$(($(date +%s%N)/1000000))"
    local res=$(curl -s -L "$SRUN_PORTAL_API?$params")
    if [[ "$res" == *"E0000"* ]]; then
        echo '[Login Successful]'
    elif [[ "$res" == *"ip_already_online_error"* ]]; then
        echo '[Already Online]'
    else
        echo '[Login Failed]'
        echo "Response: $res"
    fi
}

function logout() {
    local params="action=logout"
    local res=$(curl -s "$SRUN_PORTAL_API?$params")
    echo "$res"
}

# Main execution
if [[ "$1" == 'logout' ]]; then
    logout
    exit 0
elif [[ "$1" != "" ]]; then
    username="$1"
    password="$2"
else
    read -p "login/logout: " op
    if [[ "$op" == "logout" ]]; then
        logout
        exit 0
    fi
    read -p 'username: ' username
    read -s -p 'password: ' password
    echo ""
fi

init
get_token
preprocess
login
