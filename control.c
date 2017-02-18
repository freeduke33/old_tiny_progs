/*
 *
 *  ПРОВЕРКА ЗНАНИЙ СТУДЕНТОВ
 *
 */


/* подключение необходимых библиотек */
#include "vcstdio.h"
#include <stdio.h>
#include <conio.h>
#include "stdlib.h"
#include <dos.h>
#include <time.h>

/* опеделение констант */
#define MinQuestion 3 /* минимальная разница между набраной и
				 возможной отметкой */
#define Abase_size  6  /* длинна записи в файле CONTROL.DAT */
#define BUFlen    1300 /* длинна буфера данных */
#define KeyOfCode 10   /* ключ кодирования файлов данных */
#define MaxDigit 14    /* максимально возможное число ответов на 1 вопрос */
#define TimeMul  60    /* */
#define OkAnswer 5     /* из них правильных */
#define MaxQuestion 5  /* максимальное число вопросов за 1 сеанс */
#define lenA 140       /* длинна ответа */
#define lenQ 300       /* длинна вопроса */
#define LOOP 2         /* число сеансов в течении которых использованные */
		       /* вопросы не выводятся повторно */

/* для сохранения данных о проведенных сеансах */
struct savearc
	{
	char fio[21],fac[5];
	int grupp,ear,answer;
	} arc={"  ",0,0,0};

/* для хранения вопросов */
struct
	 {
	 int len,         /* длинна вопроса */
	 Ok[OkAnswer],    /* номера правильных ответов в answer */
	 time;            /* время на ответ */
	 char text[lenQ]; /* текст вопроса */
	 } question;

/* файлы для хранения */
 FILE *base,    /* вопросов и ответов */
      *abase;   /* смещение вопроса в пред. файле */

/* для хранения ответов */
struct
	{
	int long num;      /* число ответов */
	int len[MaxDigit]; /* смещение каждого в тексте */
	char text[lenA*MaxDigit]; /* тексты ответов */
	} answer;

 int long ExistQ_A; /* число вопросов записанных в файл данных */
 int MaxA,MaxQ;     /* число использованных вопросов/ответов*/
 int oldA[MaxDigit],      /* номера выведенных ответов */
     oldQ[LOOP*MaxDigit]; /* номера использованных вопросов */


struct
 {
  int border,
      bkg,
      say,
      actget,
      nactget,
      stat,
      title;
} MAPCOL;


error(char *str)
{
 urgentmsg(" ОШИБКА ",str);
};


/* поиск случайного числа */
int rndom(num,Max,old)
 int long num;
 int *old,Max;
{
int set;
int r,i;
 /* генерация случайных чисел пока не встретится не использованное */
 do{
  set=(int)(rand()%num);
  for(i=r=0;i<Max;i++) if(set==old[i]) {r=1;break;}
 }while(r);
 old[Max]=set;
 return(set);
}

int openfile(ass)
char ass[4];
{
 char basename[14]="ctrl.dat";
 char ansname[14]="ctrl.ovl";
abase=fopen(basename,ass);
if(abase==NULL)
	{
	error(" Нет файла данных Ctrl.dat ");
	return(1);
	}
base=fopen(ansname,ass);
if(base==NULL)
	{
	error(" Нет файла Ctrl.ovl ");
	return(1);
	}
return(0);
}

/* преобразование строки в число */
int getnum(offset,i,max)
int *i,max;
char *offset;
{
int num=0;
char d;

while(offset[*i]==' ')	(*i)++;

while(offset[*i]!=' '&&offset[*i]!='\r'&&(*i)<max)
 {
  d=offset[(*i)++];
  if((d>'9')||(d<'0'))
  {
   error("Неверная запись номера ответа или времени ");
   return(-1);
  }
  if((*i>max)||(d<0x20)) return(-1);
  num+=(d-'0');
 }
return(num);
}

void code(buf,len)
char *buf;
int len;
{
 register int  i;
 for(i=0;i<len;i++) buf[i]^=~i;
}
#define decode(buf,num) code(buf,num)

/* вывод случайного вопроса и ответов к нему */
int RND(int *maxKey,int wind)
{
int ret=0,num,i,j,flag,outA=1,row,col;
int long read,rr;
char str[sizeof(answer.text)];

srand((unsigned)(clock()%0xffff));
if(ExistQ_A==MaxQ) MaxQ=0;
rr=rndom(ExistQ_A,MaxQ,&oldQ); /* номер вопроса */
fseek(abase,sizeof(rr)*rr,SEEK_SET);
MaxQ++;
if(MaxQ==MaxDigit*LOOP) MaxQ=0;
fread(&read,sizeof(read),1,abase); /* read - смещение текста вопроса
						  в файле данных */
fseek(base,read,SEEK_SET);
/* далее чтение вопроса, декодирование и вывод */
fread(&question,sizeof(question)-sizeof(question.text),1,base);
fread(question.text,question.len,1,base);
decode(question.text,question.len);
sprintf(str,"%s\n",question.text);
atsay(1,0,str);
/* далее чтение ответа ... */
fread(&answer,sizeof(answer),1,base);
decode(&answer,sizeof(answer));
MaxA=0;
/* выводим в случайном порядке */
for(i=0;i<answer.num;i++)
	{
	num=rndom(answer.num,MaxA,&oldA);
	for(flag=1,j=0;j<OkAnswer;j++)
	 if(num+1==question.Ok[j])
	 {
	   if(ret==0) ret=outA;
	   else flag=0;
	   break;
	 }
	MaxA++;
	if(flag) /* если неправильный или 1 правильный */
	{
	  sprintf(str,"%s",answer.text+answer.len[num]);
	  say(str);
	  wcurspos(wind,&row,&col);
	  at(row,0);
	  sprintf(str,"%d.",outA++);
	  say(str);
	  at(row+1,0);
	 }
	}
*maxKey=outA-1;
return(ret);
}
/* очистка буфера клавиатуры */
void clrkbd()
{
while(kbhit()!=0) getch();
}

/* ожидание нажатия цифровой клавиши за определенное время */
int getchtime(time,max)
int time,max;
{
char c;
clock_t start;
char str[80];

clrkbd();
start=clock();
time=time*CLK_TCK+start;
while((time-start)>0)
{
 sprintf(str," Время :%4d сек",(int)((time-start)/CLK_TCK));
 atsay(0,60,str);
 while((kbhit())!=0)
 {
  c=getch();
  if(time<clock()) return(0);
  if((c>0x30)&&(c<=(max+0x30))) return(c);
 }
 start=clock();
}
return(0);
}
/* вывод журнала на экран */
int display()
{
 FILE *ff;
 int i,ret=1,wind,pos=0;
 int long lenf;
 char str[70];

 if((ff=fopen("Control.ctl","r+b"))==NULL) return;
 fseek(ff,0,SEEK_END);
 lenf=ftell(ff)/sizeof(arc);
 wind=wxxopen(2,17,20,62,"",
      NOADJ|CENTER,0,0,-1,32);
 wattr(wind,&MAPCOL.border,&MAPCOL.bkg,&MAPCOL.say,
	    &MAPCOL.actget,&MAPCOL.nactget,&MAPCOL.title,SET);
 do{
  fseek(ff,pos*sizeof(arc),SEEK_SET);
  wclr(wind,-1);
  woff();
  atsay(0,0,"╒══════════════════ Журнал ═════════╤════════╕");
  atsay(1,0,"│     Фамилия   И. О.   │  группа   │ оценка │");
  atsay(2,0,"╞═══════════════════════╪═══════════╪════════╡");
  for(i=pos;i<15+pos;i++)
  {
   if(fread(&arc,sizeof(arc),1,ff))
   {
    decode(&arc,sizeof(arc));
    sprintf(str,"│ %020s  │ %1d-%4s-%2d │   %2d   │",
		arc.fio,arc.ear,arc.fac,arc.grupp,arc.answer);
    atsay(i-pos+3,0,str);
   }
   else atsay(i-pos+3,0,"│                       │           │        │");
  }
  atsay(i-pos+3,0,"╘═══════════════════════╧═══════════╧════════╛");
  wshow(wind);
  won();
  switch(getone())
  {
  case CUR_UP:
    if(pos) pos--;
    break;
  case CUR_DOWN:
    if(pos+15<lenf) pos++;
    break;
  case PGUP:
    if(pos-15>0) pos-=15;
    else pos=0;
    break;
  case PGDN:
    if(pos+30<lenf) pos+=15;
    else pos=max(lenf-15,0);
    break;
  case ESC:
    ret=0;
    break;
  }
 }while(ret);
 wclose(wind);
 fclose(ff);
 return;
}
/* дозапись в файл журнала результатов прошедшего сеанса */
void output()
{
 FILE *ff;
 int n;
 char str[50];

 ff=fopen("Control.ctl","a+b");
 code(&arc,sizeof(arc));
 n=fwrite(&arc,sizeof(arc),1,ff);
 if(n==0) error("error write in history file ");
 decode(&arc,sizeof(arc));
 fclose(ff);
 sprintf(str," %s, %d-%s-%d, оценка : %d ",
 arc.fio,arc.ear,arc.fac,arc.grupp,arc.answer);
 urgentmsg(" ВНИМАНИЕ ",str);
 return;
}

int control()
{
int Ok,key,num,maxKEY,wind,wind1,wind2;
FILE *ttl;
char str[80],str1[5];

 if(openfile("r+b")) return;
 wind=wxxopen(0,0,24,79,"",
      NOADJ|CENTER|COOKED,0,0,-1,32);
 wattr(wind,&MAPCOL.border,&MAPCOL.bkg,&MAPCOL.say,
	    &MAPCOL.actget,&MAPCOL.nactget,&MAPCOL.title,SET);
 wclr(wind,-1);
 wind2=wxxopen(6,25,11,55," Укажите свои данные ",
      BORDER|BD1|NOADJ|CENTER|CURSOR,0,0,-1,32);
 wattr(wind2,&MAPCOL.border,&MAPCOL.bkg,&MAPCOL.say,
	    &MAPCOL.actget,&MAPCOL.nactget,&MAPCOL.title,SET);
 wclr(wind2,-1);
 wind1=wxxopen(10,20,24,60," ВНИМАНИЕ ",
      BORDER|BD2|NOADJ|CENTER,0,0,-1,32);
 wattr(wind1,&MAPCOL.border,&MAPCOL.bkg,&MAPCOL.say,
	     &MAPCOL.actget,&MAPCOL.nactget,&MAPCOL.title,SET);

 fseek(abase,0,SEEK_END);
 ExistQ_A=(ftell(abase)/Abase_size); /* определение числа вопросов */
/* вывод поясняющего сообщения */
 while(1)
 {
  wclr(wind1,-1);
  ttl=fopen("title.dsp","r");
  if(ttl!=NULL)
 {
  while(fgets(str,80,ttl)!=NULL) say(str);
  fclose(ttl);
  wshow(wind1);
  getone();
 }
 clrkbd();
 wclr(wind2,-1);

/* ввод необходимых данных для журнала */
 wselect(wind2);
 empty(arc.fio,20);
 atsayget(0,0,"фамилия   :",arc.fio,"Aaaaaaaaaaaaaaaaaa");
 empty(arc.fac,4);
 atsayget(1,0,"факультет :",arc.fac,"AAA");
 empty(str,2);
 atsayget(2,0,"курс      :",str,"9");
 empty(str1,3);
 atsayget(3,0,"группа    :",str1,"99");
 wshow(wind2);
 if(readgets()!=RET) break;
 whide(wind2);
 whide(wind1);
 arc.ear=atoi(str);
 arc.grupp=atoi(str1);
 arc.answer=(num=0);

/*  далее несколько вопросов ... */
 wselect(wind);
 while((num<MaxQuestion)&&((num-arc.answer)<MinQuestion))
 {
  num++;
  woff();
  wclr(wind,-1);
  sprintf(str,"%s, Вам вопрос N%d, набрано %d баллов.\n\n\r",
	      arc.fio,num,arc.answer);
  wxatsay(wind,0,0,str,MAPCOL.actget);
  Ok=RND(&maxKEY,wind);
  clrkbd();
  wshow(wind);
  won();
  key=getchtime((question.time)*TimeMul,maxKEY);
  wselect(wind);
  if((key-0x30)!=Ok) bell();
  else arc.answer++;
 }
 output();
 whide(wind);
}
fclose(base);
fclose(abase);
wclose(wind2);
wclose(wind1);
wclose(wind);
}

/* определение номеров правильных ответов */
int getAnswer(buf,i,read)
int *i,read;
char *buf;
{
 int j=-1,k;

 for(k=0;k<OkAnswer;k++) question.Ok[k]=0;

 do {
   if(++j>OkAnswer)
	{
	error("Слишком много номеров правильных ответов");
	return(-1);
	}
   question.Ok[j]=getnum(buf,i,read);
   if(*i>=read) return(0);
 } while(question.Ok[j]);

 for(k=0;k<j-1;k++)
  if(question.Ok[k]>answer.num)
  {
   error("Номер правильного ответа слишком большой.");
   return(-1);
  }
 question.time=question.Ok[--j];
 question.Ok[j]=0;
 if(j<=0)
 {
  error("Нет ни одного номера правильного ответа.");
  return(-1);
 }
 return(j);
}

/* преобразование текста вопросов в непотребную форму */
int input()
{
 FILE *fl;
 char buf[BUFlen+1],name[64],*point=NULL;
 int i,n,MaxLen;
 int offset=0,wind,wind1;
 int long wh,record=0,len,read=BUFlen,begin;

 buf[BUFlen]=0;
 wind=wxxopen(12,25,17,55," Создание ",
      BORDER|BD3|NOADJ|CENTER,0,0,-1,32);
 wattr(wind,&MAPCOL.border,&MAPCOL.bkg,&MAPCOL.say,
	    &MAPCOL.actget,&MAPCOL.nactget,&MAPCOL.title,SET);
 wclr(wind,-1);
 atsay(0,3,"Исходный файл вопросов");

 if(openfile("w+b")) return;
 wind1=wxxopen(14,10,16,70," Введите имя файла ",
      BORDER|BD2|NOADJ|CENTER|CURSOR,0,0,-1,32);
 wattr(wind1,&MAPCOL.border,&MAPCOL.bkg,&MAPCOL.say,
	    &MAPCOL.say,&MAPCOL.say,&MAPCOL.actget,SET);
 wclr(wind1,-1);
 wshow(wind);
 wshow(wind1);
 empty(name,50);
 at(0,0);
 accept(name,"xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx");
 wclose(wind1);
 wselect(wind);
if((fl=fopen(name,"r+b"))==NULL)
	{
	error(" файл вх. данных не найден ");
	goto end;
	}
for(n=i=0;name[i];i++)
{
 if(name[i]=='\\') n=i;
 if(name[i]==' ') name[i]=0;
}
 sprintf(buf,"%s",&name[n]);
 atsay(1,4,buf);
fseek(fl,0,SEEK_END);
len=ftell(fl);
fseek(fl,0,SEEK_SET);
while(len>0)
	{
	if((len-=BUFlen)<0) read=len+BUFlen;
	if(fread(&buf,read,1,fl)==0L)
	 {
	 error(" Ошибка при чтении файла данных ");
	 goto end;
	 }
	for(i=0;i<read;i++)
	 switch(buf[i])
	 {
	  case '&':   /* начало записи */
	   i++;
	   switch(buf[i])
	   {
	   case 'B': /* далее вопрос */
	    record++;
	    n=0;
	    sprintf(name,"Bопрос : %3d ",record);
	    atsay(2,8,name);
	    point=question.text;
	    begin=i-1;
	    MaxLen=sizeof(question.text);
	    while(buf[i]!='\n') i++;
	    offset=0;
	   break;
	   case 'O': /* далее ответы */
	    point=answer.text;
	    offset++;
	    question.len=offset;
	    MaxLen=sizeof(answer.text);
	    question.text[offset]=(answer.len[0]=0);
	    n++;
	    while(buf[i]!='\n')i++;
	    offset=0;
	   break;
	   case '&': /* далее время и номера правильных ответов */
	    if((answer.num=(--n))<1)
	    {
	     error(" Нет выбора возможных ответов ");
	     goto end;
	    }
	    i++;
	    if((n=getAnswer(&buf,&i,read))<0) goto end;
	    if(n)
	    {
	     while(buf[i]!='\n')i++;
	     offset++;
	     fseek(base,0,SEEK_END);
	     wh=ftell(base);
	     fwrite(&wh,sizeof(wh),1,abase);
	     code(question.text,question.len);
	     fwrite(&question,sizeof(question)-sizeof(question.text)+
		    question.len,1,base);
	     code(&answer,sizeof(answer));
	     fwrite(&answer,sizeof(answer)-sizeof(answer.text)+
		    offset,1,base);
	     offset=0;
	     point=NULL;
	     break;
	    }
	   default:
	    if((len<=0)||(i<read))
	    {
	     error(" Некорректный формат файла ");
	     goto end;
	    }
	    fseek(fl,(begin-=read),SEEK_CUR);
	    len-=begin;
	    record--;
	   }
	 break;
	 case '\n': break;
	 case ';':
	  if(n)
	  {
	   if(n==MaxDigit)
	   {
	    sprintf(name,"Ответов больше чем %d\n",MaxDigit);
	    error(name);
	    goto end;
	   }
	   point[offset++]=0;
	   answer.len[n]=offset;
	   n++;
	   while(buf[i]!='\n')i++;
	   break;
	  }
	 default:
	  if(offset>=MaxLen)
	  {
	   error(" Слишком большая длинна вопроса или ответов ");
	   goto end;
	  }
	  if(!point) break;
	  point[offset++]=buf[i];
	  point[offset]=0;
	 }

	}	/* end while */
woff();
wxatsay(wind,3,0,"      База данных готова     ",MAPCOL.actget);
won();
getone();
end:
fclose(fl);
fclose(base);
fclose(abase);
wclose(wind);
return;
}


int delESCkey(VCMENU *m)
{
 if(m->keyhit==ESC&&m->calledby==NULL)
       m->keyhit=CUR_UP;
 return(GOOD);
}

vcexit()
{
 vcend(CLOSE);
 exit(0);
}

void main(void)
{
 VCMENU *menu,*menunew();

  vcstart(CLRSCRN);

   MAPCOL.nactget=vc.cyan+vc.bold+vc.bg*vc.blue;
   MAPCOL.actget= vc.blue+vc.bg*vc.white;
   MAPCOL.bkg=    vc.cyan+vc.bg*vc.blue;
   MAPCOL.border= vc.white+vc.bg*vc.blue;
   MAPCOL.say=    vc.white+vc.bg*vc.blue;
   MAPCOL.title=  vc.cyan+vc.bg*vc.blue;

 addvcmstyle("$1$",HORIZONTAL|TITLECENTER,50,
   MAPCOL.nactget,
   MAPCOL.actget,
   MAPCOL.bkg,
   MAPCOL.border,0);

 menu=menunew(10,15," КОНТРОЛЬ ",NULL,"$1$");
 menuitem(menu,"",NULLFUNC,NULL,NULL,UNAVAILABLE);
 menuitem(menu," Создание ",input,NULL,NULL,STRPARM);
 menuitem(menu,"  Экзамен ",control,NULL,NULL,STRPARM);
 menuitem(menu,"  Журнал  ",display,NULL,NULL,STRPARM);
 menuitem(menu," Выход ",vcexit,NULL,NULL,STRPARM);
 vcmhook3=delESCkey;
 VC_VIO=0;
 vcmenu(menu);
}
