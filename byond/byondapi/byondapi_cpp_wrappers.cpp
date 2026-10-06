#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "byondapi_cpp_wrappers.h"

#if defined(WIN32) && defined(_MSC_VER)
#pragma warning(disable : 4996)	// disable bogus deprecation warning
#endif

/*
	C++ wrapper defs
 */

// returning ByondValueResult from a function will automatically detach it
ByondValueResult::operator CByondValue() const {return value;}

ByondExtException::ByondExtException() {str = NULL;}
ByondExtException::ByondExtException(char const *msg) {str = msg ? strdup(msg) : NULL;}
ByondExtException::ByondExtException(ByondExtException const &other) {
	str = other.str ? strdup(other.str) : NULL;
}
ByondExtException::~ByondExtException() {free(str);}
ByondExtException& ByondExtException::operator=(ByondExtException const &other) {
	if(this != &other) {
		free(str);
		str = other.str ? strdup(other.str) : NULL;
	}
	return *this;
}
char const *ByondExtException::ToString() {return str;}

void NoByondExtException(char const *e) {}
void ThrowByondExtException(char const *e) {throw ByondExtException(e);}
THREAD_VAR void (*byondExceptionHandler)(char const *) = &NoByondExtException;

CatchingByondExceptions::CatchingByondExceptions() {
	old = byondExceptionHandler;
	byondExceptionHandler = &ThrowByondExtException;
}
CatchingByondExceptions::~CatchingByondExceptions() {
	byondExceptionHandler = old;
}



ByondValue::ByondValue() {ByondValue_Clear(&value);}
ByondValue::ByondValue(ByondValueType type, u4c ref) {ByondValue_SetRef(&value,type,ref); ByondValue_IncRef(&value);}
ByondValue::ByondValue(float f) {ByondValue_SetNum(&value,f);}
ByondValue::ByondValue(char const *str) {ByondValue_SetStr(&value,str); ByondValue_IncRef(&value);}
#ifdef _STRING_
ByondValue::ByondValue(std::string &str) {ByondValue_SetStr(&value,str.c_str()); ByondValue_IncRef(&value);}
#endif
ByondValue::ByondValue(CByondValue const &src) {	// attaches value, no incref
	value = src;
}
ByondValue::ByondValue(ByondValue const &src) {	// assigns value, increfs
	ByondValue_IncRef(&src.value);
	value = src.value;
}
ByondValue::ByondValue(ByondValue &&src) {
	value = src.value;
	ByondValue_Clear(&src.value);
}
ByondValue::~ByondValue() {
	ByondValue_DecRef(&value);
}

ByondValue& ByondValue::Attach(CByondValue const &src) {
	ByondValue_DecRef(&value);
	value = src;
	return *this;
}
ByondValue &ByondValue::Assign(CByondValue const &src) {
	if(value.type == src.type && value.data.ref == src.data.ref) return *this;
	ByondValue_IncRef(&src);
	ByondValue_DecRef(&value);
	value = src;
	return *this;
}
CByondValue ByondValue::Detach() {
	CByondValue ret = value;
	ByondValue_Clear(&value);
	return ret;
}

ByondValue &ByondValue::operator=(float f) {
	ByondValue_DecRef(&value);
	ByondValue_SetNum(&value,f);
	return *this;
}
ByondValue &ByondValue::operator=(char const *str) {
	CByondValue tmp;
	ByondValue_SetStr(&tmp,str);
	return (*this = tmp);
}
ByondValue &ByondValue::operator=(CByondValue const &src) {
	if(value.type == src.type && value.data.ref == src.data.ref) return *this;
	ByondValue_IncRef(&src);
	ByondValue_DecRef(&value);
	value = src;
	return *this;
}
ByondValue &ByondValue::operator=(ByondValue const &src) {
	if(*this == src) return *this;
	ByondValue_IncRef(&src.value);
	ByondValue_DecRef(&value);
	value = src.value;
	return *this;
}
ByondValue &ByondValue::operator=(ByondValue &&src) {
	if(this == &src) return *this;
	ByondValue_DecRef(&value);
	value = src.value;
	ByondValue_Clear(&src.value);
	return *this;
}
bool ByondValue::operator==(CByondValue const &v) const {return ByondValue_Equals(&value, &v);}
bool ByondValue::operator!=(CByondValue const &v) const {return !ByondValue_Equals(&value, &v);}
ByondValue::operator bool() const {return ByondValue_IsTrue(&value);}

ByondValue::operator CByondValue() const {return value;}
ByondValue::operator CByondValue const &() const {return value;}
ByondValue::operator ByondValueResult() {
	ByondValueResult ret;
	ret.value = value;
	ByondValue_Clear(&value);
	return ret;
}

void ByondValue::Clear() {ByondValue_DecRef(&value); ByondValue_Clear(&value);}
ByondValueType ByondValue::GetType() const {return value.type;}

bool ByondValue::IsNull() const {return ByondValue_IsNull(&value);}
bool ByondValue::IsNum() const {return ByondValue_IsNum(&value);}
bool ByondValue::IsStr() const {return ByondValue_IsStr(&value);}
bool ByondValue::IsList() const {return ByondValue_IsList(&value);}
bool ByondValue::IsTrue() const {return ByondValue_IsTrue(&value);}
bool ByondValue::IsType(char const *typestr) const {return ByondValue_IsType(&value,typestr);}

float ByondValue::GetNum() const {return ByondValue_GetNum(&value);}
u4c ByondValue::GetRef() const {return ByondValue_GetRef(&value);}

void ByondValue::SetNum(float f) {
	ByondValue_DecRef(&value);
	ByondValue_SetNum(&value,f);
}
void ByondValue::SetStr(char const *str) {
	CByondValue tmp;
	ByondValue_SetStr(&tmp,str);
	Attach(tmp);
}
void ByondValue::SetRef(ByondValueType type, u4c ref) {
	CByondValue tmp;
	ByondValue_SetRef(&tmp,type,ref);
	Attach(tmp);
}

void ByondValue::IncRef() {ByondValue_IncRef(&value);}
void ByondValue::DecRef() {ByondValue_DecRef(&value);}
bool ByondValue::TestRef() {return Byond_TestRef(&value);}

bool ByondValue::Equiv(CByondValue const &other) const {return ByondValue_Equiv(&value,&other);}

ByondValue &ByondValue::Swap(ByondValue &other) {
	CByondValue tmp = value;
	value = other.value;
	other.value = tmp;
	return *this;
}

bool ByondValue::ToString(char *buf, u4c *buflen) const {return Byond_ToString(&value,buf,buflen);}
#ifdef _STRING_
std::string ByondValue::ToString() const {return Byond_ToString(*this);}
void ByondValue::ToString(std::string &result) const {Byond_ToString(*this,result);}
#endif

char *_byondlasterrbuf=NULL;
u4c _byondlasterrbuflen=0;
char const *Byond_LastError() {
	u4c len = _byondlasterrbuflen;
	while(!Byond_LastError(_byondlasterrbuf, &len)) {
		if(!len) return "";
		char *newbuf = (char *)malloc(len);
		if(!newbuf) return "";	// unable to allocate memory
		free(_byondlasterrbuf);
		_byondlasterrbuf = newbuf;
		_byondlasterrbuflen = len;
	}
	return _byondlasterrbuf;
}

/*
	All of the C++-wrapped Byond_ functions call byondExceptionHandler on failure.

	If you define a CatchingByondExceptions var in a try block, it will change
	byondExceptionHandler to throw a ByondExtException you can catch.
 */

ByondValue Byond_ReadVar(CByondValue const &loc, char const *varname) {
	ByondValue result;
	bool success = Byond_ReadVar(&loc, varname, &result.value);
	if(!success) byondExceptionHandler(Byond_LastError());
	return result;
}
ByondValue Byond_ReadVarByStrId(CByondValue const &loc, u4c varname) {
	ByondValue result;
	bool success = Byond_ReadVarByStrId(&loc, varname, &result.value);
	if(!success) byondExceptionHandler(Byond_LastError());
	return result;
}
void Byond_WriteVar(CByondValue const &loc, char const *varname, CByondValue const &val) {
	bool success = Byond_WriteVar(&loc, varname, &val);
	if(!success) byondExceptionHandler(Byond_LastError());
}
void Byond_WriteVarByStrId(CByondValue const &loc, u4c varname, CByondValue const &val) {
	bool success = Byond_WriteVarByStrId(&loc, varname, &val);
	if(!success) byondExceptionHandler(Byond_LastError());
}

ByondValue Byond_CreateList(u4c len) {
	ByondValue result;
	bool success = Byond_CreateListLen(&result.value, len);
	if(!success) byondExceptionHandler(Byond_LastError());
	return result;
}
ByondValue Byond_CreateList(CByondValue const *list, u4c len) {
	ByondValue result;
	bool success = Byond_CreateList(&result.value);
	if(!success) byondExceptionHandler(Byond_LastError());
	success = Byond_WriteList(&result.value, list, len);
	if(!success) byondExceptionHandler(Byond_LastError());
	return result;
}
ByondValue Byond_CreateList(ByondValue const *list, u4c len) {return Byond_CreateList((CByondValue const *)list,len);}	// lazy cast
#ifdef _VECTOR_
ByondValue Byond_CreateList(std::vector<CByondValue> const &list) {return Byond_CreateList(list.data(), list.size());}
ByondValue Byond_CreateList(std::vector<ByondValue> const &list) {return Byond_CreateList((ByondValue const *)list.data(), list.size());}
#endif
ByondValue Byond_CreateDimensionalList(u4c const *sizes, u4c dimension) {
	ByondValue result;
	bool success = Byond_CreateDimensionalList(&result.value, sizes, dimension);
	if(!success) byondExceptionHandler(Byond_LastError());
	return result;
}

bool Byond_ReadList(CByondValue const &loc, ByondValue *list, u4c *len) {
	if(list) {for(u4c i=*len; i--;) list[i].Clear();}
	bool success = Byond_ReadList(&loc, (CByondValue*)list, len);
	if(!success && !*len) byondExceptionHandler(Byond_LastError());
	return success;
}
bool Byond_ReadListAssoc(CByondValue const &loc, ByondValue *list, u4c *len) {
	if(list) {for(u4c i=*len; i--;) list[i].Clear();}
	bool success = Byond_ReadList(&loc, (CByondValue*)list, len);
	if(!success && !*len) byondExceptionHandler(Byond_LastError());
	return success;
}
void Byond_WriteList(CByondValue const &loc, CByondValue const *list, u4c len) {
	bool success = Byond_WriteList(&loc, list, len);
	if(!success) byondExceptionHandler(Byond_LastError());
}
void Byond_WriteList(CByondValue const &loc, ByondValue const *list, u4c len) {return Byond_WriteList(loc,(CByondValue const *)list, len);}	// lazy cast

#ifdef _VECTOR_
struct SyncByondReadListData {
	CByondValue const *loc;
	std::vector<ByondValue> *list;
	SyncByondReadListData(CByondValue const &loc, std::vector<ByondValue> &list): loc(&loc), list(&list) {}
};
CByondValue _SyncByond_ReadList_STL(void *data) {
	SyncByondReadListData *sync = (SyncByondReadListData*)data;
	std::vector<ByondValue> *list = sync->list;
	CByondValue ret;
	u4c len = list->capacity();
	for(auto i=list->size(); i--;) (*list)[i].Clear();
	while(!Byond_ReadList(sync->loc, (CByondValue*)list->data(), &len)) {
		if(!len) {ByondValue_SetNum(&ret,0); return ret;}
		try {list->resize(len);} catch(...) {Byond_SetLastError("failed to allocate memory"); ByondValue_SetNum(&ret,0); return ret;}
	}
	ByondValue_SetNum(&ret,1);
	return ret;
}
void Byond_ReadList(CByondValue const &loc, std::vector<ByondValue> &list) {
	CByondValue result = Byond_ThreadSync(_SyncByond_ReadList_STL,&list);
	if(!ByondValue_GetNum(&result)) byondExceptionHandler(Byond_LastError());
}
std::vector<ByondValue> Byond_ReadList(CByondValue const &loc) {
	std::vector<ByondValue> list;
	Byond_ReadList(loc,list);
	return list;
}

CByondValue _SyncByond_ReadListAssoc_STL(void *data) {
	SyncByondReadListData *sync = (SyncByondReadListData*)data;
	std::vector<ByondValue> *list = sync->list;
	CByondValue ret;
	u4c len = list->capacity();
	for(auto i=list->size(); i--;) (*list)[i].Clear();
	while(!Byond_ReadListAssoc(sync->loc, (CByondValue*)list->data(), &len)) {
		if(!len) {ByondValue_SetNum(&ret,0); return ret;}
		try {list->resize(len);} catch(...) {Byond_SetLastError("failed to allocate memory"); ByondValue_SetNum(&ret,0); return ret;}
	}
	ByondValue_SetNum(&ret,1);
	return ret;
}
void Byond_ReadListAssoc(CByondValue const &loc, std::vector<ByondValue> &list) {
	SyncByondReadListData sync(loc,list);
	CByondValue result = Byond_ThreadSync(_SyncByond_ReadListAssoc_STL,&sync);
	if(!ByondValue_GetNum(&result)) byondExceptionHandler(Byond_LastError());
}
std::vector<ByondValue> Byond_ReadListAssoc(CByondValue const &loc) {
	std::vector<ByondValue> list;
	Byond_ReadListAssoc(loc,list);
	return list;
}

void Byond_WriteList(CByondValue const &loc, std::vector<CByondValue> const &list) {
	bool success = Byond_WriteList(&loc, list.data(), list.size());
	if(!success) byondExceptionHandler(Byond_LastError());
}
void Byond_WriteList(CByondValue const &loc, std::vector<ByondValue> const &list) {
	bool success = Byond_WriteList(&loc, (CByondValue const *)list.data(), list.size());
	if(!success) byondExceptionHandler(Byond_LastError());
}
#endif

ByondValue Byond_ReadListIndex(CByondValue const &loc, CByondValue const &idx) {
	ByondValue result;
	bool success = Byond_ReadListIndex(&loc, &idx, &result.value);
	if(!success) byondExceptionHandler(Byond_LastError());
	return result;
}
void Byond_WriteListIndex(CByondValue const &loc, CByondValue const &idx, CByondValue const &val) {
	bool success = Byond_WriteListIndex(&loc, &idx, &val);
	if(!success) byondExceptionHandler(Byond_LastError());
}


ByondValue Byond_ReadPointer(CByondValue const &ptr) {
	ByondValue result;
	bool success = Byond_ReadPointer(&ptr, &result.value);
	if(!success) byondExceptionHandler(Byond_LastError());
	return result;
}
void Byond_WritePointer(CByondValue const &ptr, CByondValue const &val) {
	bool success = Byond_WritePointer(&ptr, &val);
	if(!success) byondExceptionHandler(Byond_LastError());
}

ByondValue Byond_CallProc(CByondValue const &src, char const *name, CByondValue const *arg, u4c arg_count) {
	ByondValue result;
	bool success = Byond_CallProc(&src,name,arg,arg_count,&result.value);
	if(!success) byondExceptionHandler(Byond_LastError());
	return result;
}
ByondValue Byond_CallProc(CByondValue const &src, char const *name, ByondValue const *arg, u4c arg_count) {return Byond_CallProc(src,name,(CByondValue const *)arg,arg_count);}	// lazy cast


ByondValue Byond_CallProcByStrId(CByondValue const &src, u4c name, CByondValue const *arg, u4c arg_count) {
	ByondValue result;
	bool success = Byond_CallProcByStrId(&src,name,arg,arg_count,&result.value);
	if(!success) byondExceptionHandler(Byond_LastError());
	return result;
}
ByondValue Byond_CallProcByStrId(CByondValue const &src, u4c name, ByondValue const *arg, u4c arg_count) {return Byond_CallProcByStrId(src,name,(CByondValue const *)arg,arg_count);}	// lazy cast

ByondValue Byond_CallGlobalProc(char const *name, CByondValue const *arg, u4c arg_count) {
	ByondValue result;
	bool success = Byond_CallGlobalProc(name,arg,arg_count,&result.value);
	if(!success) byondExceptionHandler(Byond_LastError());
	return result;
}
ByondValue Byond_CallGlobalProc(char const *name, ByondValue const *arg, u4c arg_count) {return Byond_CallGlobalProc(name,(CByondValue const *)arg,arg_count);}	// lazy cast

ByondValue Byond_CallGlobalProcByStrId(u4c name, CByondValue const *arg, u4c arg_count) {
	ByondValue result;
	bool success = Byond_CallGlobalProcByStrId(name,arg,arg_count,&result.value);
	if(!success) byondExceptionHandler(Byond_LastError());
	return result;
}
ByondValue Byond_CallGlobalProcByStrId(u4c name, ByondValue const *arg, u4c arg_count) {return Byond_CallGlobalProcByStrId(name,(CByondValue const *)arg,arg_count);}	// lazy cast

bool Byond_ToString(CByondValue const &src, char *buf, u4c *buflen) {
	bool success = Byond_ToString(&src,buf,buflen);
	if(!success && !*buflen) byondExceptionHandler(Byond_LastError());
	return success;
}
#ifdef _STRING_
struct SyncByondToStringData {
	CByondValue const *loc;
	std::string *str;
	SyncByondToStringData(CByondValue const &loc, std::string &str): loc(&loc), str(&str) {}
};
CByondValue _SyncByond_ToString_STL(void *data) {
	CByondValue ret;
	SyncByondToStringData *sync = (SyncByondToStringData*)data;
	std::string *str = sync->str;
	u4c len = str->capacity();
	while(!Byond_ToString(sync->loc, const_cast<char*>(str->data()), &len)) {
		if(!len) {ByondValue_SetNum(&ret,0); return ret;}
		try {str->reserve(len);} catch(...) {Byond_SetLastError("failed to allocate memory"); ByondValue_SetNum(&ret,0); return ret;}
	}
	str->assign(str->data(), len-1);
	ByondValue_SetNum(&ret,1);
	return ret;
}
void Byond_ToString(CByondValue const &src, std::string &str) {
	SyncByondToStringData sync(src,str);
	CByondValue result = Byond_ThreadSync(_SyncByond_ToString_STL,&sync);
	if(!ByondValue_GetNum(&result)) byondExceptionHandler(Byond_LastError());
}
std::string Byond_ToString(CByondValue const &src) {
	std::string str;
	Byond_ToString(src,str);
	return str;
}
#endif

bool Byond_Return(CByondValue const &waiting_proc, CByondValue const &retval) {return Byond_Return(&waiting_proc,&retval);}

// builtins
bool Byond_Block(CByondXYZ const &corner1, CByondXYZ const &corner2, CByondValue *list, u4c *len) {
	bool success = Byond_Block(&corner1,&corner2,list,len);
	if(!success && !*len) byondExceptionHandler(Byond_LastError());
	return success;
}
#ifdef _VECTOR_
struct SyncByondBlockData {
	CByondXYZ const *corner1;
	CByondXYZ const *corner2;
	std::vector<ByondValue> *list;
	SyncByondBlockData(CByondXYZ const &corner1, CByondXYZ const &corner2, std::vector<ByondValue> &list): corner1(&corner1), corner2(&corner2), list(&list) {}
};
CByondValue _SyncByond_Block_STL(void *data) {
	CByondValue ret;
	SyncByondBlockData *sync = (SyncByondBlockData*)data;
	std::vector<ByondValue> *list = sync->list;
	u4c len = list->capacity();
	for(auto i=list->size(); i--;) (*list)[i].Clear();	// turfs don't incref but clear the old values if they're not turfs
	while(!Byond_Block(sync->corner1, sync->corner2, (CByondValue*)list->data(), &len)) {
		if(!len) {ByondValue_SetNum(&ret,0); return ret;}
		try {list->resize(len);} catch(...) {Byond_SetLastError("failed to allocate memory"); ByondValue_SetNum(&ret,0); return ret;}
	}
	ByondValue_SetNum(&ret,1);
	return ret;
}
void Byond_Block(CByondXYZ const &corner1, CByondXYZ const &corner2, std::vector<ByondValue> &list) {
	SyncByondBlockData sync(corner1,corner2,list);
	CByondValue result = Byond_ThreadSync(_SyncByond_Block_STL,&sync);
	if(!ByondValue_GetNum(&result)) byondExceptionHandler(Byond_LastError());
}
std::vector<ByondValue> Byond_Block(CByondXYZ const &corner1, CByondXYZ const &corner2) {
	std::vector<ByondValue> list;
	Byond_Block(corner1,corner2,list);
	return list;
}
#endif

bool ByondValue_IsType(ByondValue const &src, char const *typestr) {
	return ByondValue_IsType(&src.value,typestr);
}

ByondValue Byond_Length(ByondValue const &src) {
	ByondValue result;
	bool success = Byond_Length(&src.value,&result.value);
	if(!success) byondExceptionHandler(Byond_LastError());
	return result;
}

ByondValue Byond_Locate(ByondValue const &type) {
	ByondValue result;
	bool success = Byond_LocateIn(&type.value, NULL, &result.value);
	if(!success) byondExceptionHandler(Byond_LastError());
	return result;
}

ByondValue Byond_LocateIn(ByondValue const &type, ByondValue const &list) {
	ByondValue result;
	bool success = Byond_LocateIn(&type.value, &list.value, &result.value);
	if(!success) byondExceptionHandler(Byond_LastError());
	return result;
}

ByondValue Byond_LocateXYZ(CByondXYZ const &xyz) {
	ByondValue result;
	Byond_LocateXYZ(&xyz, &result.value);	// return value is always true
	return result;
}

ByondValue Byond_New(ByondValue const &src, CByondValue const *arg, u4c arg_count) {
	ByondValue result;
	bool success = Byond_New(&src.value,arg,arg_count,&result.value);
	if(!success) byondExceptionHandler(Byond_LastError());
	return result;
}
ByondValue Byond_New(ByondValue const &src, ByondValue const *arg, u4c arg_count) {return Byond_New(src,(CByondValue const *)arg,arg_count);}	// lazy cast

ByondValue Byond_NewArglist(ByondValue const &src, ByondValue const &arglist) {
	ByondValue result;
	bool success = Byond_NewArglist(&src.value,&arglist.value,&result.value);
	if(!success) byondExceptionHandler(Byond_LastError());
	return result;
}

u4c Byond_Refcount(ByondValue const &src) {
	u4c result;
	bool success = Byond_Refcount(&src.value,&result);
	if(!success) byondExceptionHandler(Byond_LastError());
	return result;
}

CByondXYZ Byond_XYZ(ByondValue const &src) {
	CByondXYZ xyz;
	bool success = Byond_XYZ(&src.value,&xyz);
	if(!success) byondExceptionHandler(Byond_LastError());
	return xyz;
}

CByondPixLoc Byond_PixLoc(ByondValue const &src) {
	CByondPixLoc pixloc;
	bool success = Byond_PixLoc(&src.value,&pixloc);
	if(!success) byondExceptionHandler(Byond_LastError());
	return pixloc;
}

CByondPixLoc Byond_BoundPixLoc(ByondValue const &src, u1c dir) {
	CByondPixLoc pixloc;
	bool success = Byond_BoundPixLoc(&src.value,dir,&pixloc);
	if(!success) byondExceptionHandler(Byond_LastError());
	return pixloc;
}
