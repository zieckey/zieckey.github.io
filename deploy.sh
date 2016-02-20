#

hugo --theme=hugo-rapid-theme
sleep 1
mv public/ public.new
git co master
cp public.new/* . -rf
rm public.new/ -rf
git add *
git ci -a -m'new release'
git push
