#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

key="${DEPLOY_SSH_KEY:-$HOME/.ssh/id_ed25519_beisi_cicd}"
host="${DEPLOY_HOST:-root@121.41.119.56}"
dest="${DEPLOY_DEST:-/opt/1panel/www/sites/copyup.beisi.tech/index}"
site_url="${DEPLOY_URL:-https://copyup.beisi.tech/}"
ssh_cmd=(ssh -o BatchMode=yes -o IdentitiesOnly=yes -i "$key")

if [[ ! -f "$key" ]]; then
  echo "找不到 SSH 私钥: $key" >&2
  exit 1
fi

echo "本机构建"
npm run build

if [[ ! -f dist/index.html ]]; then
  echo "构建产物缺少 dist/index.html，已停止上传" >&2
  exit 1
fi

package_dir="$(cd "$root/.." && pwd)/.build/dist"
latest="$(find "$package_dir" -maxdepth 1 -type f -name 'CopyUp-*-arm64.dmg' -print0 | xargs -0 stat -f '%m %N' | sort -nr | head -n 1 | cut -d' ' -f2-)"
if [[ -z "$latest" || ! -f "$latest" ]]; then
  echo "找不到官网安装包：$package_dir/CopyUp-*-arm64.dmg" >&2
  exit 1
fi
mkdir -p dist/download
cp "$latest" dist/download/CopyUp.dmg
echo "安装包: $(basename "$latest")"

echo "确认服务器目录"
"${ssh_cmd[@]}" "$host" "test \"\$(readlink -f '$dest')\" = '/opt/1panel/www/sites/copyup.beisi.tech/index'"

echo "上传构建产物"
rsync -az --delete --exclude '.DS_Store' \
  -e "ssh -o BatchMode=yes -o IdentitiesOnly=yes -i ${key}" \
  "$root/dist/" "${host}:${dest}/"

echo "检查线上页面"
body_file="$(mktemp)"
cleanup() {
  rm -f "$body_file"
}
trap cleanup EXIT

status="$(curl -sS --max-time 20 -o "$body_file" -w '%{http_code}' "$site_url")"
if [[ "$status" != "200" ]]; then
  echo "线上访问失败: $site_url 返回 HTTP $status" >&2
  exit 1
fi

phrases=(
  "简单优雅的剪切板工具"
  "官网版免费，保存 10 条历史和 5 条收藏。"
  "剪切板内容均本地处理，不上传云端。"
)
for phrase in "${phrases[@]}"; do
  if ! grep -q "$phrase" "$body_file"; then
    echo "线上页面缺少：$phrase" >&2
    exit 1
  fi
done

asset="$(sed -nE 's/.*href="\.\/(assets\/[^"]+\.css)".*/\1/p' "$body_file" | head -n 1)"
if [[ -z "$asset" ]]; then
  echo "线上页面没有找到样式文件" >&2
  exit 1
fi

asset_status="$(curl -sS --max-time 20 -o /dev/null -w '%{http_code}' "${site_url}${asset}")"
if [[ "$asset_status" != "200" ]]; then
  echo "样式文件访问失败: ${site_url}${asset} 返回 HTTP $asset_status" >&2
  exit 1
fi

download_result="$(curl -sS --max-time 60 -o /dev/null -w '%{http_code} %{size_download}' "${site_url}download/CopyUp.dmg")"
download_status="${download_result%% *}"
download_size="${download_result##* }"
if [[ "$download_status" != "200" || "$download_size" -lt 1000000 ]]; then
  echo "安装包访问失败: ${site_url}download/CopyUp.dmg 返回 HTTP $download_status，大小 $download_size" >&2
  exit 1
fi

echo "部署完成: $site_url"
