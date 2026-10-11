<?php
/**
 * Reteste de segurança — cadastro + reposição de palavra-passe (2026-10-11).
 * Exercita o fluxo real de reposição e confirma os fixes nos ficheiros.
 */
chdir('/root/work/itest'); require_once 'init.php';
use \Firebase\JWT\JWT;
error_reporting(E_ALL); ini_set('display_errors','stderr');
ob_start(); // TMessage/TScript escrevem HTML — fica no buffer
register_shutdown_function(function(){ while(ob_get_level()){ echo ob_get_clean(); } });
$ok=0;$f=0; function chk($c,$m){global $ok,$f; fwrite(STDERR,($c?'OK    ':'FALHA ').$m."\n"); $c?$ok++:$f++;}

/* esquema + utilizador */
@unlink('/root/work/itest/test.db'); $pdo=new PDO('sqlite:/root/work/itest/test.db');
foreach(array_filter(array_map('trim',explode(";\n",file_get_contents('/root/work/itest_scripts/schema_novo.sql')))) as $s){ try{$pdo->exec($s);}catch(Throwable $e){} }
function ins($pdo,$t,$r){$c=array_keys($r);$q=implode(',',array_map(fn($x)=>'"'.$x.'"',$c));$ph=implode(',',array_fill(0,count($c),'?'));$st=$pdo->prepare("INSERT INTO $t ($q) VALUES ($ph)");$st->execute(array_values($r));return (int)$pdo->lastInsertId();}
ins($pdo,'account',['id'=>1,'razao_social'=>'Oficina A']);
ins($pdo,'system_unit',['id'=>1,'name'=>'Sede','account_id'=>1]);
$velha=password_hash('OldPass1', PASSWORD_DEFAULT);
ins($pdo,'system_users',['id'=>5,'name'=>'Rita','login'=>'rita@x.pt','email'=>'rita@x.pt','password'=>$velha,'active'=>'Y','account_id'=>1,'system_unit_id'=>1]);

$ini=AdiantiApplicationConfig::get(); $seed=APPLICATION_NAME.($ini['general']['seed']??'');
function tokenPara($pwHash,$seed,$expira='+1 hour'){
  return JWT::encode(['user'=>'rita@x.pt','fp'=>substr(hash('sha256',(string)$pwHash.$seed),0,16),'expires'=>strtotime($expira)],$seed,'HS256');
}
function pwAtual($pdo){ $r=$pdo->query("SELECT password FROM system_users WHERE id=5")->fetch(); return $r['password']; }
function repor($token,$p1,$p2=null){ try{ ResetSenhaForm::onResetSenha(['token'=>$token,'password1'=>$p1,'password2'=>$p2??$p1]); }catch(Throwable $e){} if(TTransaction::get()){try{TTransaction::close();}catch(Throwable $e){}} }

fwrite(STDERR,"== Reposição de palavra-passe ==\n");
// 1) reposição válida → grava BCRYPT (não md5)
$t1=tokenPara($velha,$seed);
repor($t1,'NovaPass1');
$pw1=pwAtual($pdo);
chk(strpos($pw1,'$2y$')===0 || strpos($pw1,'$2b$')===0, "nova palavra-passe guardada em bcrypt (não md5)");
chk(password_verify('NovaPass1',$pw1), "a nova palavra-passe funciona");
chk(strlen($pw1)!==32, "não é um hash md5 de 32 hex");

// 2) uso único: reusar o MESMO link (fp da senha antiga) → recusado, senha não muda
repor($t1,'HackPass9');
$pw2=pwAtual($pdo);
chk($pw2===$pw1 && !password_verify('HackPass9',$pw2), "link reutilizado é recusado (uso único)");

// 3) força mínima: token novo (fp da senha atual) + senha fraca → recusado
$t2=tokenPara($pw1,$seed);
repor($t2,'123');
chk(pwAtual($pdo)===$pw1, "palavra-passe fraca recusada (sem mudar nada)");

// 4) token expirado → recusado
$t3=tokenPara($pw1,$seed,'-10 minutes');
repor($t3,'OutraPass1');
chk(pwAtual($pdo)===$pw1 && !password_verify('OutraPass1',pwAtual($pdo)), "token expirado recusado");

// 5) fp errado (token forjado com impressão inválida) → recusado
$tbad=JWT::encode(['user'=>'rita@x.pt','fp'=>'000000000000','expires'=>strtotime('+1 hour')],$seed,'HS256');
repor($tbad,'OutraPass1');
chk(pwAtual($pdo)===$pw1, "token com impressão inválida recusado");

/* ---- Verificações estáticas dos ficheiros (os fixes estão no código) ---- */
fwrite(STDERR,"\n== Verificações nos ficheiros ==\n");
$reset=file_get_contents('app/control/saas_admin/ResetSenhaForm.php');
$esq  =file_get_contents('app/control/saas_admin/EsqueciSenhaForm.php');
$cad  =file_get_contents('cadastrar.php');
chk(strpos($reset,'md5(')===false, "ResetSenhaForm já não usa md5()");
chk(strpos($reset,'password_hash(')!==false, "ResetSenhaForm usa password_hash (bcrypt)");
chk(strpos($esq,'HTTP_REFERER')===false, "EsqueciSenhaForm já não usa HTTP_REFERER");
chk(strpos($esq,'Se existir uma conta')!==false, "EsqueciSenhaForm tem mensagem neutra (anti-enumeração)");
chk(strpos($cad,'fromArray((array) $data)')===false && strpos($cad,'fromArray((array)$data)')===false, "cadastrar.php já não faz mass-assignment (fromArray do POST)");
chk(substr_count($cad,'h($_POST')>=5, "cadastrar.php escapa as saídas (anti-XSS)");
chk(strpos($cad,"name=\"csrf\"")!==false && strpos($cad,'csrf_cadastro')!==false, "cadastrar.php tem token anti-CSRF");
chk(strpos($cad,'name="website"')!==false, "cadastrar.php tem honeypot anti-robô");
chk(strpos($cad,'FILTER_VALIDATE_EMAIL')!==false, "cadastrar.php valida o email no servidor");
chk(strpos($cad,'senhaForte(')!==false, "cadastrar.php exige força mínima de palavra-passe");

fwrite(STDERR,"\n== RESULTADO: $ok OK, $f FALHA(S)\n");
exit($f?1:0);
