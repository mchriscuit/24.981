jaeger = read.table("BoersmaLevelt-JaegerSim.weights",header=TRUE,sep="\t")
names(jaeger)

names(jaeger) = c("Time","NoCoda","Onset","NoComplexOnset","NoComplexCoda","Faith")

# Get some colors for the plots
colors <- rainbow(ncol(jaeger))

# Set up the plot
plot(jaeger$Time, jaeger$Faith, axes=FALSE, xlab="Number of observations", ylab="weight", ylim=c(0,14),xlim=c(0,5000), type="n",)
axis(1,at=seq(0,10000,by=2000))
axis(2,at=seq(0,14))
box()
for (i in 2:ncol(jaeger))
{
    lines(jaeger$Time, jaeger[,i],col=colors[i],lwd=2)
}
legend(3300,12.5,legend=colnames(jaeger)[2:ncol(jaeger)], col=colors[2:ncol(jaeger)], lty=1, bty="n")