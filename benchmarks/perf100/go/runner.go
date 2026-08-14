package main

import (
 "fmt"
 "os"
 "strconv"
)

const mod int64 = 1000000007
func gcd(a,b int64) int64 { for b!=0 { a,b=b,a%b }; return a }
func kernel(f int,n,seed int64) int64 {
 acc:=seed
 switch f {
 case 1: for i:=int64(1);i<=n;i++ { acc=(acc+i)%mod }
 case 2: for i:=int64(1);i<=n;i++ { x:=i%10000;acc=(acc+x*x)%mod }
 case 3: x:=seed;for i:=int64(0);i<n;i++ { x=(x*482+1)%1000003;acc=(acc+x)%mod }
 case 4: for i:=int64(1);i<=n;i++ { if (i+seed)%7<3 {acc+=i%1009} else {acc+=mod-i%997};acc%=mod }
 case 5: for i:=int64(1);i<=n;i++ {acc=(acc+gcd(i*17+seed,i*13+97))%mod}
 case 6: acc=0;for i:=int64(1);i<=n;i++ {x:=(i+seed)%100000+1;for x!=1 {if x%2==0{x/=2}else{x=x*3+1};acc++}};acc%=mod
 case 7: acc=0;for x:=int64(2);x<=n;x++ {prime:=true;for d:=int64(2);d<=x/d&&prime;d++ {prime=x%d!=0};if prime{acc++}}
 case 8: acc=0;for x:=int64(1);x<=n;x++ {for d:=int64(1);d<=x/d;d++ {if x%d==0 {acc+=d;if d!=x/d{acc+=x/d};acc%=mod}}}
 case 9: acc=0;for i:=int64(0);i<n;i++ {a,b:=seed,seed+1;for s:=0;s<24;s++ {a,b=b,(a+b)%mod};acc=(acc+b+i%17)%mod}
 case 10: acc=0;for i:=int64(0);i<n;i++ {x,p:=(i+seed)%1009,int64(17);for c:=int64(1);c<=12;c++ {p=(p*x+c*13)%1000003};acc=(acc+p)%mod}
 case 11: acc=seed;for i:=int64(1);i<=n;i++ {for j:=int64(1);j<=i;j++ {acc=(acc+(i+j)%97)%mod}}
 case 12: x,lo,hi:=seed,mod,int64(0);for i:=int64(0);i<n;i++ {x=(x*482+1)%1000003;if x<lo{lo=x};if x>hi{hi=x}};acc=(lo+hi)%mod
 case 13,14,15,16:
  v:=make([]int64,n);for i:=int64(0);i<n;i++ {v[i]=((i%1009)*37+seed)%1009};acc=0
  if f==13 {for _,x:=range v {acc=(acc+x)%mod}}
  if f==14 {for i:=n;i>0;i-- {acc=(acc+v[i-1])%mod}}
  if f==15 {for p:=int64(0);p<16;p++ {for i:=p;i<n;i+=16 {acc=(acc+v[i])%mod}}}
  if f==16 {for i:=int64(1);i<n;i++ {v[i]=(v[i]+v[i-1])%mod};acc=v[n-1]}
 case 17: v:=make([]int64,n);x:=seed;for i:=int64(0);i<n;i++ {x=(x*482+1)%1000003;v[i]=x};for i:=int64(1);i<n;i++ {z,j:=v[i],i;for j>0&&v[j-1]>z {v[j]=v[j-1];j--};v[j]=z};acc=(v[0]+v[n/2]+v[n-1])%mod
 case 18:
  limit:=int64(0);for limit+1<=n/(limit+1){limit++};base:=make([]int64,limit+1);for p:=int64(2);p<=limit/p;p++{if base[p]==0{for m:=p*p;m<=limit;m+=p{base[m]=1}}}
  const segmentSize int64=32768;segment:=make([]int64,segmentSize);acc=0
  for low:=int64(2);low<=n;{high:=low+segmentSize-1;if high>n{high=n};active:=high-low+1;for i:=int64(0);i<active;i++{segment[i]=0};for p:=int64(2);p<=limit;p++{if base[p]==0{start:=((low+p-1)/p)*p;if start<p*p{start=p*p};for m:=start;m<=high;m+=p{segment[m-low]=1}}};for i:=int64(0);i<active;i++{if segment[i]==0{acc++}};low=high+1}
 case 19: cells:=n*n;a:=make([]int64,cells);b:=make([]int64,cells);c:=make([]int64,cells);for i:=int64(0);i<cells;i++ {a[i]=(i*17+seed)%101;b[i]=(i*31+seed)%103};for r:=int64(0);r<n;r++ {for k:=int64(0);k<n;k++ {for col:=int64(0);col<n;col++ {c[r*n+col]+=a[r*n+k]*b[k*n+col]}}};acc=0;for _,x:=range c {acc=(acc+x)%mod}
 case 20: v:=make([]int64,n);for i:=int64(0);i<n;i++ {v[i]=i*2+seed};acc=0;for q:=int64(0);q<n;q++ {target,lo,hi:=(((q%100000)*7919)%n)*2+seed,int64(0),n;for lo<hi {m:=lo+(hi-lo)/2;if v[m]<target{lo=m+1}else{hi=m}};acc=(acc+lo)%mod}
 default: os.Exit(2)
 }
 return acc
}
func main(){if len(os.Args)!=4{os.Exit(2)};f,e:=strconv.Atoi(os.Args[1]);if e!=nil{panic(e)};n,e:=strconv.ParseInt(os.Args[2],10,64);if e!=nil{panic(e)};s,e:=strconv.ParseInt(os.Args[3],10,64);if e!=nil{panic(e)};fmt.Println(kernel(f,n,s))}
