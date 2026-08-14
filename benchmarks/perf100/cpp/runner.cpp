// The scalar implementation keeps the workload and data layout aligned with
// the other Perf100 runners while allowing the C++ optimizer to work normally.
#include <cstdint>
#include <cstdlib>
#include <iostream>
#include <numeric>
#include <vector>

using i64 = std::int64_t;
static constexpr i64 MOD = 1000000007;

static i64 run_kernel(int f, i64 n, i64 seed) {
  i64 acc = seed;
  if (f == 1) for (i64 i=1;i<=n;++i) acc=(acc+i)%MOD;
  else if (f == 2) for (i64 i=1;i<=n;++i) { auto x=i%10000; acc=(acc+x*x)%MOD; }
  else if (f == 3) { i64 x=seed; for(i64 i=0;i<n;++i){x=(x*482+1)%1000003;acc=(acc+x)%MOD;} }
  else if (f == 4) for(i64 i=1;i<=n;++i){acc += (i+seed)%7<3 ? i%1009 : MOD-i%997;acc%=MOD;}
  else if (f == 5) for(i64 i=1;i<=n;++i) acc=(acc+std::gcd(i*17+seed,i*13+97))%MOD;
  else if (f == 6) { acc=0; for(i64 i=1;i<=n;++i){i64 x=(i+seed)%100000+1;while(x!=1){x=x%2==0?x/2:x*3+1;++acc;}}acc%=MOD; }
  else if (f == 7) { acc=0; for(i64 x=2;x<=n;++x){bool p=true;for(i64 d=2;d<=x/d&&p;++d)p=x%d!=0;acc+=p;} }
  else if (f == 8) { acc=0;for(i64 x=1;x<=n;++x)for(i64 d=1;d<=x/d;++d)if(x%d==0){acc=(acc+d+(d!=x/d?x/d:0))%MOD;} }
  else if (f == 9) { acc=0;for(i64 i=0;i<n;++i){i64 a=seed,b=seed+1;for(int s=0;s<24;++s){auto z=(a+b)%MOD;a=b;b=z;}acc=(acc+b+i%17)%MOD;} }
  else if (f == 10) { acc=0;for(i64 i=0;i<n;++i){i64 x=(i+seed)%1009,p=17;for(int c=1;c<=12;++c)p=(p*x+c*13)%1000003;acc=(acc+p)%MOD;} }
  else if (f == 11) { acc=seed;for(i64 i=1;i<=n;++i)for(i64 j=1;j<=i;++j)acc=(acc+(i+j)%97)%MOD; }
  else if (f == 12) { i64 x=seed,lo=MOD,hi=0;for(i64 i=0;i<n;++i){x=(x*482+1)%1000003;lo=std::min(lo,x);hi=std::max(hi,x);}acc=(lo+hi)%MOD; }
  else if (f>=13&&f<=16) { std::vector<i64> v(n);for(i64 i=0;i<n;++i)v[i]=((i%1009)*37+seed)%1009;acc=0;
    if(f==13)for(auto x:v)acc=(acc+x)%MOD; if(f==14)for(auto i=n;i>0;--i)acc=(acc+v[i-1])%MOD;
    if(f==15)for(i64 p=0;p<16;++p)for(i64 i=p;i<n;i+=16)acc=(acc+v[i])%MOD;
    if(f==16){for(i64 i=1;i<n;++i)v[i]=(v[i]+v[i-1])%MOD;acc=v[n-1];} }
  else if (f==17) { std::vector<i64> v(n);i64 x=seed;for(i64 i=0;i<n;++i){x=(x*482+1)%1000003;v[i]=x;}for(i64 i=1;i<n;++i){auto z=v[i],j=i;while(j>0&&v[j-1]>z){v[j]=v[j-1];--j;}v[j]=z;}acc=(v[0]+v[n/2]+v[n-1])%MOD; }
  else if (f==18) {
    i64 limit=0;while(limit+1<=n/(limit+1))++limit;
    std::vector<i64> base(limit+1,0);for(i64 p=2;p<=limit/p;++p)if(base[p]==0)for(i64 m=p*p;m<=limit;m+=p)base[m]=1;
    constexpr i64 segment_size=32768;std::vector<i64> segment(segment_size,0);acc=0;
    for(i64 low=2;low<=n;){i64 high=std::min(low+segment_size-1,n),active=high-low+1;for(i64 i=0;i<active;++i)segment[i]=0;
      for(i64 p=2;p<=limit;++p)if(base[p]==0){i64 start=((low+p-1)/p)*p;if(start<p*p)start=p*p;for(i64 m=start;m<=high;m+=p)segment[m-low]=1;}
      for(i64 i=0;i<active;++i)if(segment[i]==0)++acc;low=high+1;}
  }
  else if (f==19) { auto cells=n*n;std::vector<i64>a(cells),b(cells),c(cells);for(i64 i=0;i<cells;++i){a[i]=(i*17+seed)%101;b[i]=(i*31+seed)%103;}for(i64 r=0;r<n;++r)for(i64 k=0;k<n;++k)for(i64 col=0;col<n;++col)c[r*n+col]+=a[r*n+k]*b[k*n+col];acc=0;for(auto x:c)acc=(acc+x)%MOD; }
  else if (f==20) { std::vector<i64>v(n);for(i64 i=0;i<n;++i)v[i]=i*2+seed;acc=0;for(i64 q=0;q<n;++q){i64 target=(((q%100000)*7919)%n)*2+seed,lo=0,hi=n;while(lo<hi){auto m=lo+(hi-lo)/2;if(v[m]<target)lo=m+1;else hi=m;}acc=(acc+lo)%MOD;} }
  else std::exit(2);
  return acc;
}

int main(int argc,char**argv){if(argc!=4)return 2;std::cout<<run_kernel(std::atoi(argv[1]),std::strtoll(argv[2],nullptr,10),std::strtoll(argv[3],nullptr,10))<<'\n';}
