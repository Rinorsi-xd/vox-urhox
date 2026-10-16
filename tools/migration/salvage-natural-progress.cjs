const flat=(a,b)=>Math.hypot(a[0]-b[0],a[2]-b[2]);
class NaturalProgress {
 constructor(){this.anchor=null;this.stillAt=0;this.reverseUntil=0;}
 update(position,now){
  if(!this.anchor||flat(position,this.anchor)>=1){this.anchor=[...position];this.stillAt=now;}
  if(now<this.reverseUntil)return true;
  if(this.reverseUntil){this.reverseUntil=0;this.anchor=[...position];this.stillAt=now;}
  if(now-this.stillAt>7000){this.reverseUntil=now+1600;return true;}
  return false;
 }
}
module.exports={NaturalProgress};
