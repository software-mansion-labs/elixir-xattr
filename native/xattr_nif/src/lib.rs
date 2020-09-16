use rustler::{Atom, Binary, Env, Error, NifResult, OwnedBinary};
use std::io::Error as IoError;
use std::io::Write;
use std::os::unix::ffi::OsStrExt;
use xattr;

mod atoms {
    rustler::atoms! {
        eperm,
        enoent,
        e2big,
        eagain,
        efault,
        enospc,
        erange,
        enoattr, // compat name
        enotsup,
        edquot,
        ok,
    }
}

const EPERM: i32 = 1;
const ENOENT: i32 = 2;
const E2BIG: i32 = 7;
const EAGAIN: i32 = 11;
const EFAULT: i32 = 14;
const ENOSPC: i32 = 28;
const ERANGE: i32 = 34;
const ENODATA: i32 = 61;
const ENOTSUP: i32 = 95;
const EDQUOT: i32 = 144;

fn build_error<T>(error: IoError) -> NifResult<T> {
    Err(Error::Term(match error.raw_os_error() {
        Some(EPERM) => Box::new(atoms::eperm()),
        Some(ENOENT) => Box::new(atoms::enoent()),
        Some(E2BIG) => Box::new(atoms::e2big()),
        Some(EAGAIN) => Box::new(atoms::eagain()),
        Some(EFAULT) => Box::new(atoms::efault()),
        Some(ENOSPC) => Box::new(atoms::enospc()),
        Some(ERANGE) => Box::new(atoms::erange()),
        Some(ENODATA) => Box::new(atoms::enoattr()),
        Some(ENOTSUP) => Box::new(atoms::enotsup()),
        Some(EDQUOT) => Box::new(atoms::edquot()),
        Some(num) => Box::new(num.to_string()),
        None => {
            // println!("error: {}", error);
            // println!("error kind: {:?}", error.kind());
            Box::new(error.to_string())
        }
    }))
}

/// Converts a Rust string to an Erlang string (binary)
fn str2bin<'a>(env: Env<'a>, bytes: &[u8]) -> Binary<'a> {
    let mut ob = OwnedBinary::new(bytes.len()).unwrap();
    ob.as_mut_slice().write_all(bytes).unwrap();
    ob.release(env)
}

#[rustler::nif]
fn xattr_native_nif() -> bool {
    return true;
}

/// Macro rules to make the ok/error atom boilerplate shrink
macro_rules! make_result {
    // with mapping, an {:ok, *thing*} response
    ($expr:expr, $it:ident => { $body:expr }) => {
        match $expr {
            Ok($it) => Ok((atoms::ok(), $body)),
            Err(error) => build_error(error),
        }
    };
    // no mapping, just a simple :ok response
    ($expr:expr) => {
        match $expr {
            Ok(_) => Ok(atoms::ok()),
            Err(error) => build_error(error),
        }
    };
}

#[rustler::nif]
fn listxattr_nif<'a>(env: Env<'a>, path: &str) -> NifResult<(Atom, Vec<Binary<'a>>)> {
    return make_result!(xattr::list(path), items => {
        items.map(|x|
            str2bin(env, x.as_bytes())
        ).collect()
    });
}

#[rustler::nif]
fn hasxattr_nif(path: &str, name: &str) -> NifResult<(Atom, bool)> {
    return make_result!(xattr::get(path, name), it => { it != None });
}
#[rustler::nif]
fn getxattr_nif<'a>(env: Env<'a>, path: &str, name: &str) -> NifResult<(Atom, Binary<'a>)> {
    match xattr::get(path, name) {
        Ok(None) => Err(Error::Term(Box::new(atoms::enoattr()))),
        Ok(Some(val)) => Ok((atoms::ok(), str2bin(env, val.as_slice()))),
        Err(error) => build_error(error),
    }
}
#[rustler::nif]
fn setxattr_nif(path: &str, name: &str, value: Binary) -> NifResult<Atom> {
    return make_result!(xattr::set(path, name, value.as_slice()));
}
#[rustler::nif]
fn removexattr_nif(path: &str, name: &str) -> NifResult<Atom> {
    return make_result!(xattr::remove(path, name));
}

rustler::init!(
    "Elixir.Xattr.Nif",
    [
        listxattr_nif,
        hasxattr_nif,
        getxattr_nif,
        setxattr_nif,
        removexattr_nif,
        xattr_native_nif,
    ]
);
