{-# OPTIONS_GHC -Wall #-}
module Reporting.Error.Syntax where

import qualified Data.List as List
import qualified Text.Parsec.Error as Parsec
import qualified Text.PrettyPrint as P
import Text.PrettyPrint ((<+>))

import qualified AST.Helpers as Help
import qualified AST.Type as Type
import Elm.Utils ((|>))
import qualified Reporting.PrettyPrint as P
import qualified Reporting.Report as Report


data Error
    = Parse [Parsec.Message]
    | InfixDuplicate String
    | TypeWithoutDefinition String
    | PortWithoutAnnotation String
    | DuplicateValueDeclaration String
    | DuplicateTypeDeclaration String
    | DuplicateDefinition String
    | UnboundTypeVarsInAlias String [String] String [String] Type.Raw
    | UnboundTypeVarsInUnion String [String] String [String] [(String, [Type.Raw])]


-- TO REPORT

toReport :: Error -> Report.Report
toReport err =
  case err of
    Parse messages ->
        Report.simple
          "Problem when parsing your code!"
          (unlines (map parseErrorHint messages))

    InfixDuplicate opName ->
        Report.simple
          ("The infix declarations for " ++ operator ++ " must be removed.")
          ("The precedence and associativity can only be set in one place, and\n"
           ++ "this information has already been set somewhere else."
          )
      where
        operator =
            if Help.isOp opName
              then "(" ++ opName ++ ")"
              else "`" ++ opName ++ "`"

    TypeWithoutDefinition valueName ->
        Report.simple
          ("There is a type annotation for '" ++ valueName ++ "' but there"
            ++ "is no corresponding definition!"
          )
          ("Directly below the type annotation, put a definition like:\n\n"
            ++ "    " ++ valueName ++ " = 42"
          )

    PortWithoutAnnotation portName ->
        Report.simple
          ("Port '" ++ portName ++ "' does not have a type annotation!")
          ("Directly above the port definition, I need something like this:\n\n"
            ++ "    port " ++ portName ++ " : Signal Int"
          )

    DuplicateValueDeclaration name ->
        Report.simple
          ("Naming multiple top-level values '" ++ name ++ "' makes things\n"
            ++ "ambiguous. When you say '" ++ name ++ "' which one do you want?!"
          )
          ("Find all the top-level values named '" ++ name ++ "' and\n"
            ++ "do some renaming. Make sure the names are distinct!"
          )

    DuplicateTypeDeclaration name ->
        Report.simple
          ("Naming multiple types '" ++ name ++ "' makes things ambiguous\n"
            ++ "When you say '" ++ name ++ "' which one do you want?!"
          )
          ("Find all the types named '" ++ name ++ "' and\n"
            ++ "do some renaming. Make sure the names are distinct!"
          )

    DuplicateDefinition name ->
        Report.simple
          ("Naming multiple values '" ++ name ++ "' in a single let-expression makes\n"
            ++ "things ambiguous. When you say '" ++ name ++ "' which one do you want?!"
          )
          ("Find all the values named '" ++ name ++ "' in this let-expression and\n"
            ++ "do some renaming. Make sure the names are distinct!"
          )

    UnboundTypeVarsInAlias typeName givenVars tvar tvars tipe ->
        unboundTypeVars typeName tvar tvars $ P.render $
            P.hang
              (P.text "type alias" <+> P.text typeName <+> P.hsep vars <+> P.equals)
              4
              (P.pretty False tipe)
      where
        vars = map P.text (givenVars ++ tvar : tvars)


    UnboundTypeVarsInUnion typeName givenVars tvar tvars ctors ->
        unboundTypeVars typeName tvar tvars $ P.render $
            P.vcat
              [ P.text "type" <+> P.text typeName <+> P.hsep vars
              , map toDoc ctors
                  |> zipWith (<+>) (P.text "=" : repeat (P.text "|"))
                  |> P.vcat
                  |> P.nest 4
              ]
      where
        vars = map P.text (givenVars ++ tvar : tvars)
        toDoc (ctor, args) =
            P.text ctor <+> P.hsep (map (P.pretty True) args)


unboundTypeVars :: String -> String -> [String] -> String -> Report.Report
unboundTypeVars typeName tvar tvars revisedDeclaration =
  let
    s = if null tvars then "" else "s"
  in
    Report.simple
      ("Type '" ++ typeName ++ "' uses unbound type variable" ++ s ++ ": "
        ++ List.intercalate ", " (tvar:tvars)
      )
      ("All type variables must be listed to avoid sneaky type errors.\n"
        ++ "Imagine one '" ++ typeName ++ "' where '" ++ tvar ++ "' is an Int and\n"
        ++ "another where it is a Bool. They both look like a '" ++ typeName ++ "'\n"
        ++ "to the type checker, but they are actually different types!\n\n"
        ++ "Maybe you want a definition like this?\n"
        ++ concatMap ("\n    "++) (lines revisedDeclaration)
      )


parseErrorHint :: Parsec.Message -> String
parseErrorHint message =
  case message of
    Parsec.SysUnExpect msg ->
        "SysUnExpect: " ++ msg

    Parsec.UnExpect msg ->
        "UnExpect: " ++ msg

    Parsec.Expect msg ->
        "UnExpect: " ++ msg

    Parsec.Message msg ->
        "UnExpect: " ++ msg