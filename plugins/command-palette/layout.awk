# layout.awk — parse a tmux layout tree in a tiny DSL.
#   spec := group | leaf ; leaf := NAME[:WEIGHT] ; group := (H|V)"(" expr ("," expr)+ ")"[:WEIGHT]
# modes:
#   -v mode=figure  renders box art sized W x H
#   -v mode=plan    emits a bash plan (uses $P_ROOT; calls layout_leaf "$pane" "role")
function rd_name(   s,c){ s=""; while(pos<=length(spec)){ c=substr(spec,pos,1);
    if(c ~ /[A-Za-z0-9_.-]/){ s=s c; pos++ } else break } return s }
function rd_num(   s,c){ s=""; while(pos<=length(spec)){ c=substr(spec,pos,1);
    if(c ~ /[0-9]/){ s=s c; pos++ } else break } return s+0 }
function parse(   id,ch,nd,k,c,w){
  id=rd_name()
  if(substr(spec,pos,1)=="("){
    # grupo: só H ou V; ao menos 2 filhos; separador/parêntese obrigatórios.
    pos++; nd=++nid; t[nd]=id; k=0
    if(id!="H" && id!="V") bad=1
    while(1){
      c=parse(); w=1
      if(substr(spec,pos,1)==":"){ pos++; w=rd_num() }
      wt[c]=w; kid[nd,++k]=c
      ch=substr(spec,pos,1)
      if(ch==","){ pos++; continue }
      if(ch==")"){ pos++; break }
      bad=1; break
    }
    nkids[nd]=k; if(k<2) bad=1
    return nd
  }
  nd=++nid; t[nd]="L"; lab[nd]=id
  if(id=="") bad=1
  return nd
}
function draw(nd,x0,y0,x1,y1,    i,n,axis,x,y,w,rem,rc,remneed,tot,minrest){
  if(t[nd]=="L"){
    for(x=x0;x<=x1;x++){ hset[y0,x]=1; hset[y1,x]=1 }
    for(y=y0;y<=y1;y++){ vset[y,x0]=1; vset[y,x1]=1 }
    rx0[nd]=x0; ry0[nd]=y0; rx1[nd]=x1; ry1[nd]=y1
    return
  }
  n=nkids[nd]; axis=t[nd]
  if(axis=="H"){
    x=x0
    for(i=1;i<n;i++){
      rem=x1-x+1; rc=n-i+1; remneed=rem+rc-1; tot=0
      for(k=i;k<=n;k++) tot+=wt[kid[nd,k]]
      w=int(remneed*wt[kid[nd,i]]/tot+0.5); minrest=2*(rc-1)
      if(w>rem-minrest) w=rem-minrest
      if(w<2) w=2
      draw(kid[nd,i],x,y0,x+w-1,y1); x+=w-1
    }
    draw(kid[nd,n],x,y0,x1,y1)
  } else {
    y=y0
    for(i=1;i<n;i++){
      rem=y1-y+1; rc=n-i+1; remneed=rem+rc-1; tot=0
      for(k=i;k<=n;k++) tot+=wt[kid[nd,k]]
      w=int(remneed*wt[kid[nd,i]]/tot+0.5); minrest=2*(rc-1)
      if(w>rem-minrest) w=rem-minrest
      if(w<2) w=2
      draw(kid[nd,i],x0,y,x1,y+w-1); y+=w-1
    }
    draw(kid[nd,n],x0,y,x1,y1)
  }
}
function glyph(up,dn,lf,rt){
  if(up&&dn&&lf&&rt) return "┼"
  if(up&&dn&&rt) return "├"
  if(up&&dn&&lf) return "┤"
  if(lf&&rt&&dn) return "┬"
  if(lf&&rt&&up) return "┴"
  if(dn&&rt) return "┌"
  if(dn&&lf) return "┐"
  if(up&&rt) return "└"
  if(up&&lf) return "┘"
  if(lf||rt) return "─"
  return "│"
}
function pct_of(nd,from,to,   tot,k){
  tot=0; for(k=from;k<=to;k++) tot+=wt[kid[nd,k]]
  return tot
}
function build(nodevar,nd,    i,n,axis,cur,vname,rest,total,pct){
  if(t[nd]=="L"){ printf "layout_leaf \"$%s\" \"%s\"\n", nodevar, lab[nd]; return }
  n=nkids[nd]; axis=t[nd]; cur=nodevar
  for(i=1;i<n;i++){
    total=pct_of(nd,i,n); rest=pct_of(nd,i+1,n)
    pct=int(100*rest/total+0.5); if(pct<1) pct=1; if(pct>99) pct=99
    vname="_p" (++vn)
    printf "%s=$(tmux split-window %s -p %d -t \"$%s\" -P -F '#{pane_id}')\n",
           vname, (axis=="H"?"-h":"-v"), pct, cur
    build(cur, kid[nd,i])
    cur=vname
  }
  build(cur, kid[nd,n])
}
function roles(nd,   i,n){
  if(t[nd]=="L"){ if(!(lab[nd] in seen)){ seen[lab[nd]]=1; print lab[nd] } return }
  n=nkids[nd]
  for(i=1;i<=n;i++) roles(kid[nd,i])
}
BEGIN{
  pos=1; root=parse()
  # spec inválida nunca vira plano silencioso: falha com status != 0 e mensagem.
  if(bad || pos!=length(spec)+1){
    printf "layout.awk: especificação inválida: [%s]\n", spec > "/dev/stderr"
    exit 2
  }
  if(mode=="plan"){ vn=0; build("P_ROOT", root) }
  else if(mode=="roles"){ roles(root) }
  else{
    draw(root,1,1,W,H)
    for(id=1;id<=nid;id++){
      if(t[id]!="L") continue
      if(ry1[id]-ry0[id]<2) continue
      txt=lab[id]; iw=rx1[id]-rx0[id]-1
      if(iw<1) continue
      if(length(txt)>iw) txt=substr(txt,1,iw)
      sy=ry0[id]+int((ry1[id]-ry0[id])/2)
      sx=rx0[id]+1+int((iw-length(txt))/2)
      for(j=1;j<=length(txt);j++) L[sy,sx+j-1]=substr(txt,j,1)
    }
    for(y=1;y<=H;y++){
      line=""
      for(x=1;x<=W;x++){
        if((y SUBSEP x) in L){ line=line L[y,x]; continue }
        if(!hset[y,x] && !vset[y,x]){ line=line " "; continue }
        up=(vset[y-1,x]?1:0); dn=(vset[y+1,x]?1:0)
        lf=(hset[y,x-1]?1:0); rt=(hset[y,x+1]?1:0)
        line=line glyph(up,dn,lf,rt)
      }
      print line
    }
  }
}
