import java.util.Arrays;

public final class Perf100 {
    private static final long MOD = 1_000_000_007L;
    private static long gcd(long a, long b) { while (b != 0) { long t=a%b; a=b; b=t; } return a; }
    private static long kernel(int f, long n, long seed) {
        long acc=seed;
        if(f==1)for(long i=1;i<=n;i++)acc=(acc+i)%MOD;
        else if(f==2)for(long i=1;i<=n;i++){long x=i%10000;acc=(acc+x*x)%MOD;}
        else if(f==3){long x=seed;for(long i=0;i<n;i++){x=(x*482+1)%1000003;acc=(acc+x)%MOD;}}
        else if(f==4)for(long i=1;i<=n;i++){acc+=(i+seed)%7<3?i%1009:MOD-i%997;acc%=MOD;}
        else if(f==5)for(long i=1;i<=n;i++)acc=(acc+gcd(i*17+seed,i*13+97))%MOD;
        else if(f==6){acc=0;for(long i=1;i<=n;i++){long x=(i+seed)%100000+1;while(x!=1){x=x%2==0?x/2:x*3+1;acc++;}}acc%=MOD;}
        else if(f==7){acc=0;for(long x=2;x<=n;x++){boolean p=true;for(long d=2;d<=x/d&&p;d++)p=x%d!=0;if(p)acc++;}}
        else if(f==8){acc=0;for(long x=1;x<=n;x++)for(long d=1;d<=x/d;d++)if(x%d==0){acc+=d;if(d!=x/d)acc+=x/d;acc%=MOD;}}
        else if(f==9){acc=0;for(long i=0;i<n;i++){long a=seed,b=seed+1;for(int s=0;s<24;s++){long z=(a+b)%MOD;a=b;b=z;}acc=(acc+b+i%17)%MOD;}}
        else if(f==10){acc=0;for(long i=0;i<n;i++){long x=(i+seed)%1009,p=17;for(long c=1;c<=12;c++)p=(p*x+c*13)%1000003;acc=(acc+p)%MOD;}}
        else if(f==11){acc=seed;for(long i=1;i<=n;i++)for(long j=1;j<=i;j++)acc=(acc+(i+j)%97)%MOD;}
        else if(f==12){long x=seed,lo=MOD,hi=0;for(long i=0;i<n;i++){x=(x*482+1)%1000003;lo=Math.min(lo,x);hi=Math.max(hi,x);}acc=(lo+hi)%MOD;}
        else if(f>=13&&f<=16){long[]v=new long[(int)n];for(int i=0;i<n;i++)v[i]=((i%1009L)*37+seed)%1009;acc=0;
            if(f==13)for(long x:v)acc=(acc+x)%MOD;if(f==14)for(int i=(int)n;i>0;i--)acc=(acc+v[i-1])%MOD;
            if(f==15)for(int p=0;p<16;p++)for(int i=p;i<n;i+=16)acc=(acc+v[i])%MOD;
            if(f==16){for(int i=1;i<n;i++)v[i]=(v[i]+v[i-1])%MOD;acc=v[(int)n-1];}}
        else if(f==17){long[]v=new long[(int)n];long x=seed;for(int i=0;i<n;i++){x=(x*482+1)%1000003;v[i]=x;}for(int i=1;i<n;i++){long z=v[i];int j=i;while(j>0&&v[j-1]>z){v[j]=v[j-1];j--;}v[j]=z;}acc=(v[0]+v[(int)n/2]+v[(int)n-1])%MOD;}
        else if(f==18){long limit=0;while(limit+1<=n/(limit+1))limit++;long[]base=new long[(int)limit+1];for(long p=2;p<=limit/p;p++)if(base[(int)p]==0)for(long m=p*p;m<=limit;m+=p)base[(int)m]=1;
            final long segmentSize=32768;long[]segment=new long[(int)segmentSize];acc=0;for(long low=2;low<=n;){long high=Math.min(low+segmentSize-1,n),active=high-low+1;for(long i=0;i<active;i++)segment[(int)i]=0;
                for(long p=2;p<=limit;p++)if(base[(int)p]==0){long start=((low+p-1)/p)*p;if(start<p*p)start=p*p;for(long m=start;m<=high;m+=p)segment[(int)(m-low)]=1;}
                for(long i=0;i<active;i++)if(segment[(int)i]==0)acc++;low=high+1;}}
        else if(f==19){int cells=Math.toIntExact(n*n);long[]a=new long[cells],b=new long[cells],c=new long[cells];for(int i=0;i<cells;i++){a[i]=(i*17L+seed)%101;b[i]=(i*31L+seed)%103;}int size=(int)n;for(int r=0;r<size;r++)for(int k=0;k<size;k++)for(int col=0;col<size;col++)c[r*size+col]+=a[r*size+k]*b[k*size+col];acc=0;for(long x:c)acc=(acc+x)%MOD;}
        else if(f==20){long[]v=new long[(int)n];for(int i=0;i<n;i++)v[i]=i*2L+seed;acc=0;for(long q=0;q<n;q++){long target=(((q%100000)*7919)%n)*2+seed,lo=0,hi=n;while(lo<hi){long m=lo+(hi-lo)/2;if(v[(int)m]<target)lo=m+1;else hi=m;}acc=(acc+lo)%MOD;}}
        else throw new IllegalArgumentException("unknown family");
        return acc;
    }
    public static void main(String[] args) {
        if(args.length!=3)throw new IllegalArgumentException("family n seed");
        System.out.println(kernel(Integer.parseInt(args[0]),Long.parseLong(args[1]),Long.parseLong(args[2])));
    }
}
